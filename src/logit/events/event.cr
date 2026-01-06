require "json"
require "../log_level"
require "./attributes"

module Logit
  struct Event
    # OpenTelemetry trace fields (W3C format)
    property trace_id : String
    property span_id : String
    property parent_span_id : String?

    # Timestamps
    property timestamp : Time
    property duration_ms : Int64

    # Standard OpenTelemetry fields
    property name : String # event.name
    property level : LogLevel
    property status : Status # "ok", "error"

    # Source location (preserved via macro)
    property code_file : String
    property code_line : Int32

    # Method information
    property method_name : String
    property class_name : String

    # Structured attributes (using JSON::Any)
    property attributes : Event::Attributes

    # Exception (if any)
    property exception : ExceptionInfo?

    def initialize(@trace_id, @span_id, @name, @level, @code_file, @code_line,
                   @method_name, @class_name, @parent_span_id = nil)
      @timestamp = Time.utc
      @duration_ms = 0_i64
      @status = Status::Ok
      @attributes = Event::Attributes.new
    end

    # OpenTelemetry semantic conventions helpers
    # See: https://opentelemetry.io/docs/specs/semconv/

    # HTTP attributes
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

  enum Status
    Ok
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

  # Exception info struct
  struct ExceptionInfo
    property type : String
    property message : String
    property stacktrace : Array(String)?

    def initialize(@type, @message, @stacktrace = nil)
    end

    def self.from_exception(ex : ::Exception) : self
      new(
        ex.class.to_s,
        ex.message || "",
        ex.backtrace? || [] of String
      )
    end
  end
end
