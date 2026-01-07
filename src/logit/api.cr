require "./tracing/span"
require "./tracing/tracer"
require "./events/event"
require "./events/attributes"
require "./log_level"
require "./utils/id_generator"

module Logit
  # Direct logging methods for libraries and manual instrumentation.
  #
  # These methods provide a Crystal Log-like API for targeted logging when
  # annotations aren't appropriate (e.g., libraries, ORMs, HTTP clients).
  #
  # ## Lazy Evaluation
  #
  # Like Crystal's Log library, these methods support lazy evaluation via blocks:
  #
  # ```crystal
  # # Eager evaluation - string always computed
  # Logit.debug("Processing #{expensive_operation()}")
  #
  # # Lazy evaluation - block only executed if logging is enabled
  # Logit.debug { "Processing #{expensive_operation()}" }
  # ```
  #
  # ## Trace Context Integration
  #
  # Manual log calls automatically inherit trace context from any active span:
  #
  # ```crystal
  # @[Logit::Log]
  # def process_order(order_id : Int64)
  #   # This log call inherits the trace_id and span_id from the annotation
  #   Logit.info { "Starting order processing" }
  #
  #   validate_order(order_id)
  #
  #   Logit.info { "Order validation complete" }
  # end
  # ```
  #
  # ## Usage in Libraries
  #
  # ```crystal
  # module MyORM
  #   def self.execute_query(sql : String) : Array(Result)
  #     # Lazy debug log - only computed if debug enabled
  #     Logit.debug { "Executing query: #{sql}" }
  #
  #     results = DB.query(sql)
  #
  #     # Lazy info log with structured data
  #     Logit.info { "Query returned #{results.size} rows" }
  #
  #     results
  #   rescue ex : DB::Error
  #     # Log exceptions with full context
  #     Logit.exception("Database query failed", ex)
  #     raise ex
  #   end
  # end
  # ```
  #
  # ## Structured Attributes
  #
  # You can add structured attributes to log messages:
  #
  # ```crystal
  # Logit.warn("Slow query detected",
  #   duration_ms: 450,
  #   query: sql,
  #   table: "users"
  # )
  # ```
  module API
    extend self

    # Logs a message at Trace level.
    #
    # Supports both string and block (lazy) evaluation:
    # ```crystal
    # Logit.trace("Direct message")
    # Logit.trace { "Lazy message: #{expensive()}" }
    # ```
    def trace(message : String, **kwargs) : Nil
      log_event(LogLevel::Trace, message, **kwargs)
    end

    # Logs a message at Trace level with lazy evaluation.
    #
    # The block is only executed if trace logging is enabled.
    def trace(**kwargs, &block : -> String) : Nil
      lazy_log(LogLevel::Trace, **kwargs, &block)
    end

    # Logs a message at Debug level.
    def debug(message : String, **kwargs) : Nil
      log_event(LogLevel::Debug, message, **kwargs)
    end

    # Logs a message at Debug level with lazy evaluation.
    def debug(**kwargs, &block : -> String) : Nil
      lazy_log(LogLevel::Debug, **kwargs, &block)
    end

    # Logs a message at Info level.
    def info(message : String, **kwargs) : Nil
      log_event(LogLevel::Info, message, **kwargs)
    end

    # Logs a message at Info level with lazy evaluation.
    def info(**kwargs, &block : -> String) : Nil
      lazy_log(LogLevel::Info, **kwargs, &block)
    end

    # Logs a message at Warn level.
    def warn(message : String, **kwargs) : Nil
      log_event(LogLevel::Warn, message, **kwargs)
    end

    # Logs a message at Warn level with lazy evaluation.
    def warn(**kwargs, &block : -> String) : Nil
      lazy_log(LogLevel::Warn, **kwargs, &block)
    end

    # Logs a message at Error level.
    def error(message : String, **kwargs) : Nil
      log_event(LogLevel::Error, message, **kwargs)
    end

    # Logs a message at Error level with lazy evaluation.
    def error(**kwargs, &block : -> String) : Nil
      lazy_log(LogLevel::Error, **kwargs, &block)
    end

    # Logs a message at Fatal level.
    def fatal(message : String, **kwargs) : Nil
      log_event(LogLevel::Fatal, message, **kwargs)
    end

    # Logs a message at Fatal level with lazy evaluation.
    def fatal(**kwargs, &block : -> String) : Nil
      lazy_log(LogLevel::Fatal, **kwargs, &block)
    end

    # Logs an exception with full details.
    #
    # Creates an event at Error level with exception information including
    # type, message, and stacktrace.
    #
    # ```crystal
    # begin
    #   risky_operation
    # rescue ex : SomeError
    #   Logit.exception("Operation failed", ex)
    #   raise ex
    # end
    # ```
    def exception(message : String, ex : ::Exception, **kwargs) : Nil
      log_event_with_exception(LogLevel::Error, message, ex, **kwargs)
    end

    # Logs an exception at a specific level.
    def exception(message : String, ex : ::Exception, level : LogLevel, **kwargs) : Nil
      log_event_with_exception(level, message, ex, **kwargs)
    end

    private def log_event(level : LogLevel, message : String, **kwargs) : Nil
      # Early exit if not logging at this level
      return unless Tracer.should_emit?(level)

      emit_event(level, message, **kwargs)
    end

    private def lazy_log(level : LogLevel, **kwargs, &block : -> String) : Nil
      # Early exit if not logging at this level
      return unless Tracer.should_emit?(level)

      # Only execute block if logging is enabled
      message = block.call
      emit_event(level, message, **kwargs)
    end

    private def log_event_with_exception(level : LogLevel, message : String, ex : ::Exception, **kwargs) : Nil
      # Early exit if not logging at this level
      return unless Tracer.should_emit?(level)

      emit_event_with_exception(level, message, ex, **kwargs)
    end

    private def emit_event(level : LogLevel, message : String, **kwargs) : Nil
      # Get current span for trace context
      current_span = Span.current?

      # Create event
      event = Event.new(
        trace_id: current_span.try(&.trace_id) || Utils::IDGenerator.trace_id,
        span_id: current_span.try(&.span_id) || Utils::IDGenerator.span_id,
        parent_span_id: current_span.try(&.parent_span_id),
        name: "log.#{level.to_s.downcase}",
        level: level,
        code_file: "",
        code_line: 0,
        method_name: "log",
        class_name: "Logit"
      )

      # Add message as attribute
      event.attributes.set("log.message", message)

      # Add keyword arguments as attributes
      kwargs.each do |key, value|
        set_attribute(event, key.to_s, value)
      end

      # Emit event
      Tracer.default.emit(event)
    end

    private def emit_event_with_exception(level : LogLevel, message : String, ex : ::Exception, **kwargs) : Nil
      # Get current span for trace context
      current_span = Span.current?

      # Create event
      event = Event.new(
        trace_id: current_span.try(&.trace_id) || Utils::IDGenerator.trace_id,
        span_id: current_span.try(&.span_id) || Utils::IDGenerator.span_id,
        parent_span_id: current_span.try(&.parent_span_id),
        name: "log.#{level.to_s.downcase}",
        level: level,
        code_file: "",
        code_line: 0,
        method_name: "log",
        class_name: "Logit"
      )

      # Add message as attribute
      event.attributes.set("log.message", message)

      # Add exception info
      event.exception = ExceptionInfo.from_exception(ex)
      event.status = Status::Error

      # Add keyword arguments as attributes
      kwargs.each do |key, value|
        set_attribute(event, key.to_s, value)
      end

      # Emit event
      Tracer.default.emit(event)
    end

    # Helper to set attribute with proper typing
    private def set_attribute(event : Event, key : String, value) : Nil
      case value
      when String
        event.attributes.set(key, value)
      when Int32, Int64
        event.attributes.set(key, value.to_i64)
      when Float32, Float64
        event.attributes.set(key, value.to_f64)
      when Bool
        event.attributes.set(key, value)
      else
        event.attributes.set(key, value.to_s)
      end
    end
  end

  # Convenience methods at module level for shorter syntax.
  # These make `Logit.info { "message" }` work.

  # Logs a message at Trace level.
  def self.trace(message : String, **kwargs) : Nil
    API.trace(message, **kwargs)
  end

  # Logs a message at Trace level with lazy evaluation.
  def self.trace(**kwargs, &block : -> String) : Nil
    API.trace(**kwargs, &block)
  end

  # Logs a message at Debug level.
  def self.debug(message : String, **kwargs) : Nil
    API.debug(message, **kwargs)
  end

  # Logs a message at Debug level with lazy evaluation.
  def self.debug(**kwargs, &block : -> String) : Nil
    API.debug(**kwargs, &block)
  end

  # Logs a message at Info level.
  def self.info(message : String, **kwargs) : Nil
    API.info(message, **kwargs)
  end

  # Logs a message at Info level with lazy evaluation.
  def self.info(**kwargs, &block : -> String) : Nil
    API.info(**kwargs, &block)
  end

  # Logs a message at Warn level.
  def self.warn(message : String, **kwargs) : Nil
    API.warn(message, **kwargs)
  end

  # Logs a message at Warn level with lazy evaluation.
  def self.warn(**kwargs, &block : -> String) : Nil
    API.warn(**kwargs, &block)
  end

  # Logs a message at Error level.
  def self.error(message : String, **kwargs) : Nil
    API.error(message, **kwargs)
  end

  # Logs a message at Error level with lazy evaluation.
  def self.error(**kwargs, &block : -> String) : Nil
    API.error(**kwargs, &block)
  end

  # Logs a message at Fatal level.
  def self.fatal(message : String, **kwargs) : Nil
    API.fatal(message, **kwargs)
  end

  # Logs a message at Fatal level with lazy evaluation.
  def self.fatal(**kwargs, &block : -> String) : Nil
    API.fatal(**kwargs, &block)
  end

  # Logs an exception with full details at Error level.
  def self.exception(message : String, ex : ::Exception, **kwargs) : Nil
    API.exception(message, ex, **kwargs)
  end

  # Logs an exception at a specific level.
  def self.exception(message : String, ex : ::Exception, level : LogLevel, **kwargs) : Nil
    API.exception(message, ex, level, **kwargs)
  end
end
