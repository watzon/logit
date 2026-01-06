require "../events/attributes"
require "../events/event"
require "../utils/id_generator"
require "../log_level"

module Logit
  class Span
    property trace_id : String
    property span_id : String
    property parent_span_id : String?
    property name : String
    property start_time : Time
    property end_time : Time?
    property attributes : Event::Attributes
    property exception : ExceptionInfo?

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

    # Fiber-local span stack
    def self.current? : Span?
      fiber_stack = Fiber.current.current_logit_span
      fiber_stack.last? unless fiber_stack.empty?
    end

    def self.current : Span
      current? || raise("No active span")
    end

    def self.push(span : Span) : Nil
      fiber_stack = Fiber.current.current_logit_span
      fiber_stack.push(span)
    end

    # Optimized version that takes the span stack directly to avoid repeated Fiber.current access
    def self.push(span : Span, fiber_stack : Array(Span)) : Nil
      fiber_stack.push(span)
    end

    def self.pop : Span?
      fiber_stack = Fiber.current.current_logit_span
      fiber_stack.pop?
    end

    # Optimized version that takes the span stack directly to avoid repeated Fiber.current access
    def self.pop(fiber_stack : Array(Span)) : Span?
      fiber_stack.pop?
    end

    # Build event from span
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
      event
    end
  end
end

# Extend Fiber to hold span stack
class Fiber
  property current_logit_span : Array(Logit::Span) { [] of Logit::Span }
end
