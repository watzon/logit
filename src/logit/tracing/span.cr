require "../events/attributes"
require "../events/event"
require "../utils/id_generator"
require "../log_level"

module Logit
  # Represents a traced operation with timing, attributes, and trace context.
  #
  # Spans are the core building block of Logit's tracing system. Each instrumented
  # method call creates a span that tracks:
  # - Start and end times (for duration calculation)
  # - Trace and span IDs (for distributed tracing)
  # - Parent span ID (for call hierarchy)
  # - Custom attributes (for structured data)
  # - Exception information (if an error occurred)
  #
  # Spans are stored in a fiber-local stack, allowing safe concurrent tracing
  # across multiple fibers without interference.
  #
  # ## Accessing the Current Span
  #
  # Inside an instrumented method, you can access the current span to add
  # custom attributes:
  #
  # ```crystal
  # class OrderService
  #   @[Logit::Log]
  #   def process_order(order_id : Int32) : Bool
  #     # Add custom attributes to the current span
  #     if span = Logit::Span.current?
  #       span.attributes.set("order.priority", "high")
  #       span.attributes.set("order.items_count", 5_i64)
  #     end
  #
  #     # ... process the order
  #     true
  #   end
  # end
  # ```
  #
  # ## Trace Context
  #
  # Nested method calls automatically share the same trace ID and form a
  # parent-child relationship through span IDs:
  #
  # ```crystal
  # class PaymentService
  #   @[Logit::Log]
  #   def charge(amount : Float64) : Bool
  #     validate_amount(amount)  # Child span, same trace_id
  #     process_payment(amount)  # Child span, same trace_id
  #     true
  #   end
  #
  #   @[Logit::Log]
  #   def validate_amount(amount : Float64) : Bool
  #     amount > 0
  #   end
  #
  #   @[Logit::Log]
  #   def process_payment(amount : Float64) : Bool
  #     # ...
  #     true
  #   end
  # end
  # ```
  class Span
    # W3C trace ID (128-bit hex string) shared across all spans in a trace.
    property trace_id : String

    # Unique identifier for this span (64-bit hex string).
    property span_id : String

    # Span ID of the parent span, or nil if this is a root span.
    property parent_span_id : String?

    # Name of this span (typically the method name).
    property name : String

    # When this span started.
    property start_time : Time

    # When this span ended (set when the span completes).
    property end_time : Time?

    # Structured attributes attached to this span.
    property attributes : Event::Attributes

    # Exception information if an error occurred during this span.
    property exception : ExceptionInfo?

    # Span events that occurred during this span's lifetime.
    #
    # These are intermediate logs attached to a span, similar to
    # OpenTelemetry's Span Events. Use `add_event` to add events.
    getter events : Array(SpanEvent) = [] of SpanEvent

    # Creates a new span with the given name.
    #
    # Automatically inherits the trace ID from the current span (if any),
    # or generates a new trace ID for root spans. The parent span ID is
    # set to the current span's ID.
    def initialize(@name, @span_id = Utils::IDGenerator.span_id, @parent_span_id = nil)
      # Get or generate trace_id
      current = Span.current?
      @trace_id = current.try(&.trace_id) || Utils::IDGenerator.trace_id

      # If parent_span_id is nil, try to get it from current span
      if @parent_span_id.nil?
        @parent_span_id = current.try(&.span_id)
      end

      @start_time = Time.utc
      @attributes = Event::Attributes.new
    end

    # Returns the current span for this fiber, or nil if none is active.
    #
    # Use this to safely access the current span without raising an exception.
    #
    # ```crystal
    # if span = Logit::Span.current?
    #   span.attributes.set("custom.field", "value")
    # end
    # ```
    def self.current? : Span?
      fiber_stack = Fiber.current.current_logit_span
      fiber_stack.last? unless fiber_stack.empty?
    end

    # Returns the current span for this fiber.
    #
    # Raises an exception if no span is active. Prefer `current?` unless you're
    # certain a span exists.
    def self.current : Span
      current? || raise("No active span")
    end

    # Pushes a span onto the fiber-local span stack.
    #
    # This is called automatically by the instrumentation macros. You typically
    # don't need to call this directly.
    def self.push(span : Span) : Nil
      fiber_stack = Fiber.current.current_logit_span
      fiber_stack.push(span)
    end

    # Optimized version that takes the span stack directly to avoid repeated Fiber.current access.
    # Used internally by the instrumentation macros.
    def self.push(span : Span, fiber_stack : Array(Span)) : Nil
      fiber_stack.push(span)
    end

    # Pops the current span from the fiber-local span stack.
    #
    # This is called automatically by the instrumentation macros. You typically
    # don't need to call this directly.
    def self.pop : Span?
      fiber_stack = Fiber.current.current_logit_span
      fiber_stack.pop?
    end

    # Optimized version that takes the span stack directly to avoid repeated Fiber.current access.
    # Used internally by the instrumentation macros.
    def self.pop(fiber_stack : Array(Span)) : Span?
      fiber_stack.pop?
    end

    # Adds a span event (intermediate log within a span).
    #
    # This allows logging important events during long-running operations
    # without creating separate spans. Events are attached to this span
    # and included when the span is converted to an Event.
    #
    # ## Usage
    #
    # ```crystal
    # @[Logit::Log]
    # def process_large_file(path : String) : Result
    #   span = Logit::Span.current
    #
    #   span.add_event("file.opened", path: path)
    #
    #   results = process_chunks(path)
    #
    #   span.add_event("file.processed",
    #     path: path,
    #     chunks: results.size
    #   )
    #
    #   results
    # end
    # ```
    #
    # ## OpenTelemetry Compatibility
    #
    # Span events map directly to OpenTelemetry Span Events, allowing for
    # rich observability without creating separate spans for every operation.
    def add_event(name : String, **attributes) : Nil
      event_attrs = Event::Attributes.new

      attributes.each do |key, value|
        case value
        when String
          event_attrs.set(key.to_s, value)
        when Int32, Int64
          event_attrs.set(key.to_s, value.to_i64)
        when Float32, Float64
          event_attrs.set(key.to_s, value.to_f64)
        when Bool
          event_attrs.set(key.to_s, value)
        else
          event_attrs.set(key.to_s, value.to_s)
        end
      end

      @events << SpanEvent.new(
        name: name,
        timestamp: Time.utc,
        attributes: event_attrs
      )
    end

    # Converts this span to an Event for logging.
    #
    # Called automatically when a span completes. You typically don't need
    # to call this directly.
    def to_event(trace_id : String, level : LogLevel, code_file : String, code_line : Int32,
                 method_name : String, class_name : String) : Event
      end_time = @end_time || Time.utc
      duration = (end_time - @start_time).total_milliseconds.to_i64

      event = Event.new(
        trace_id: trace_id,
        span_id: @span_id,
        parent_span_id: @parent_span_id,
        name: @name,
        level: level,
        code_file: code_file,
        code_line: code_line,
        method_name: method_name,
        class_name: class_name
      )
      event.attributes = @attributes
      event.exception = @exception
      event.duration_ms = duration
      event.span_events = @events
      event
    end
  end

  # Represents an event that occurred during a span's lifetime.
  #
  # Span events are intermediate logs attached to a span, similar to
  # OpenTelemetry's Span Events. They capture significant moments during
  # a span's execution without creating separate spans.
  #
  # ## Example
  #
  # ```crystal
  # span.add_event("cache.hit", key: "user:123")
  # span.add_event("db.query.started", table: "users")
  # span.add_event("db.query.completed", rows: 42)
  # ```
  struct SpanEvent
    # Name of this event (e.g., "cache.hit", "db.query.started").
    getter name : String

    # When this event occurred.
    getter timestamp : Time

    # Structured attributes for this event.
    getter attributes : Event::Attributes

    def initialize(@name : String, @timestamp : Time, @attributes : Event::Attributes)
    end

    # Serialize to JSON
    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "name", @name
        json.field "timestamp", @timestamp.to_utc.to_s("%Y-%m-%dT%H:%M:%S.%6NZ")
        unless @attributes.values.empty?
          json.field "attributes" do
            @attributes.to_json(json)
          end
        end
      end
    end
  end
end

# Extends Fiber to hold the span stack for distributed tracing.
#
# Each fiber maintains its own stack of spans, ensuring that concurrent
# fibers don't interfere with each other's trace context.
class Fiber
  # The stack of active Logit spans for this fiber.
  # Used internally by `Logit::Span` for trace context management.
  property current_logit_span : Array(Logit::Span) { [] of Logit::Span }
end
