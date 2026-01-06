require "json"
require "../log_level"
require "./attributes"

module Logit
  # A structured log event with OpenTelemetry-compatible fields.
  #
  # Events are the core data structure passed to backends for logging. Each
  # event contains:
  # - Trace context (trace_id, span_id, parent_span_id)
  # - Timing information (timestamp, duration)
  # - Source location (file, line, method, class)
  # - Structured attributes
  # - Exception information (if applicable)
  #
  # Events are created automatically by the instrumentation system. You
  # typically interact with events through the `Span` API or by implementing
  # custom formatters/backends.
  #
  # ## OpenTelemetry Semantic Conventions
  #
  # Events provide helper methods for setting OpenTelemetry semantic attributes:
  #
  # ```crystal
  # if span = Logit::Span.current?
  #   # HTTP attributes
  #   span.attributes.set("http.method", "POST")
  #   span.attributes.set("http.route", "/api/users")
  #   span.attributes.set("http.status_code", 200_i64)
  #
  #   # Database attributes
  #   span.attributes.set("db.system", "postgresql")
  #   span.attributes.set("db.statement", "SELECT * FROM users")
  # end
  # ```
  #
  # ## JSON Serialization
  #
  # Events serialize to JSON in an OpenTelemetry-compatible format:
  #
  # ```json
  # {
  #   "trace_id": "abc123...",
  #   "span_id": "def456...",
  #   "timestamp": "2024-01-15T10:30:00.000000Z",
  #   "duration_ms": 42,
  #   "name": "find_user",
  #   "level": "info",
  #   "code": {
  #     "file": "user_service.cr",
  #     "line": 15,
  #     "function": "find_user",
  #     "namespace": "UserService"
  #   },
  #   "attributes": { ... }
  # }
  # ```
  struct Event
    # W3C trace ID (128-bit hex string) shared across all spans in a trace.
    property trace_id : String

    # Unique identifier for the span that generated this event.
    property span_id : String

    # Span ID of the parent span, or nil if this is a root span.
    property parent_span_id : String?

    # When this event was created.
    property timestamp : Time

    # Duration of the operation in milliseconds.
    property duration_ms : Int64

    # Name of this event (typically the method name).
    property name : String

    # Log level of this event.
    property level : LogLevel

    # Status of the operation (Ok or Error).
    property status : Status

    # Source file where the instrumented method is defined.
    property code_file : String

    # Line number where the instrumented method is defined.
    property code_line : Int32

    # Name of the instrumented method.
    property method_name : String

    # Fully-qualified class name containing the instrumented method.
    property class_name : String

    # Structured attributes attached to this event.
    property attributes : Event::Attributes

    # Exception information if an error occurred.
    property exception : ExceptionInfo?

    # Creates a new event with the given parameters.
    def initialize(@trace_id, @span_id, @name, @level, @code_file, @code_line,
                   @method_name, @class_name, @parent_span_id = nil)
      @timestamp = Time.utc
      @duration_ms = 0_i64
      @status = Status::Ok
      @attributes = Event::Attributes.new
    end

    # OpenTelemetry semantic conventions helpers.
    # These methods provide a convenient way to set commonly-used attributes
    # following OpenTelemetry naming conventions.
    # See: https://opentelemetry.io/docs/specs/semconv/

    # Sets the HTTP request method (e.g., "GET", "POST").
    def set_http_method(method : String) : Nil
      @attributes.set("http.method", method)
    end

    def set_http_route(route : String) : Nil
      @attributes.set("http.route", route)
    end

    def set_http_status_code(code : Int32) : Nil
      @attributes.set("http.status_code", code.to_i64)
    end

    def set_http_request_body_size(size : Int64) : Nil
      @attributes.set("http.request_body.size", size)
    end

    # Database attributes
    def set_db_system(system : String) : Nil
      @attributes.set("db.system", system)
    end

    def set_db_name(name : String) : Nil
      @attributes.set("db.name", name)
    end

    def set_db_statement(statement : String) : Nil
      @attributes.set("db.statement", statement)
    end

    def set_db_operation(operation : String) : Nil
      @attributes.set("db.operation", operation)
    end

    # User attributes
    def set_user_id(id : String | Int64) : Nil
      @attributes.set("enduser.id", id.to_s)
    end

    def set_user_role(role : String) : Nil
      @attributes.set("enduser.role", role)
    end

    # Exception attributes
    def set_exception_type(type : String) : Nil
      @attributes.set("exception.type", type)
    end

    def set_exception_message(message : String) : Nil
      @attributes.set("exception.message", message)
    end

    # Code attributes
    def set_code_function(function : String) : Nil
      @attributes.set("code.function", function)
    end

    def set_code_namespace(namespace : String) : Nil
      @attributes.set("code.namespace", namespace)
    end

    # Service attributes
    def set_service_name(name : String) : Nil
      @attributes.set("service.name", name)
    end

    def set_service_version(version : String) : Nil
      @attributes.set("service.version", version)
    end

    # Serialize to JSON
    def to_json(json : JSON::Builder) : Nil
      json.object do
        # Trace context
        json.field "trace_id", @trace_id
        json.field "span_id", @span_id
        json.field "parent_span_id", @parent_span_id if @parent_span_id

        # Timestamp
        json.field "timestamp", @timestamp.to_utc.to_s("%Y-%m-%dT%H:%M:%S.%6NZ")
        json.field "duration_ms", @duration_ms

        # Event info
        json.field "name", @name
        json.field "level", @level.to_s
        json.field "status", @status.to_s

        # Source location
        json.field "code" do
          json.object do
            json.field "file", @code_file
            json.field "line", @code_line
            json.field "function", @method_name
            json.field "namespace", @class_name
          end
        end

        # Attributes
        unless @attributes.values.empty?
          json.field "attributes" do
            @attributes.to_json(json)
          end
        end

        # Exception
        if ex = @exception
          json.field "exception" do
            json.object do
              json.field "type", ex.type
              json.field "message", ex.message
              json.field "stacktrace", ex.stacktrace if ex.stacktrace
            end
          end
        end
      end
    end

    def to_json : String
      String.build do |io|
        JSON.build(io) do |json|
          to_json(json)
        end
      end
    end
  end

  # Status of an event/span, following OpenTelemetry conventions.
  enum Status
    # The operation completed successfully.
    Ok

    # The operation encountered an error.
    Error

    def to_s(io : IO) : Nil
      io << to_s
    end

    def to_s : String
      case self
      when Ok    then "ok"
      when Error then "error"
      else
        "unknown"
      end
    end
  end

  # Structured exception information for log events.
  #
  # Captures exception details in a format suitable for logging and
  # analysis. Created automatically when an exception occurs in an
  # instrumented method.
  struct ExceptionInfo
    # The exception class name (e.g., "ArgumentError").
    property type : String

    # The exception message.
    property message : String

    # Stack trace as an array of strings, or nil if not available.
    property stacktrace : Array(String)?

    # Creates a new ExceptionInfo with the given details.
    def initialize(@type, @message, @stacktrace = nil)
    end

    # Creates an ExceptionInfo from a Crystal exception.
    def self.from_exception(ex : ::Exception) : self
      new(
        ex.class.to_s,
        ex.message || "",
        ex.backtrace? || [] of String
      )
    end
  end
end
