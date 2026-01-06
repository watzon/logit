require "json"

module Logit
  struct LogEntry
    property timestamp : Time
    property level : LogLevel
    property method_name : String
    property class_name : String
    property file : String
    property line : Int32
    property arguments : Hash(String, String)?
    property return_value : String?
    property exception : Exception?
    property context : Hash(String, String)
    property duration : Time::Span?
    property metadata : Hash(String, String)

    def initialize(@timestamp, @level, @method_name, @class_name,
                   @file, @line, @arguments = nil, @context = Context.current)
      @metadata = {} of String => String
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "timestamp", @timestamp.to_utc.to_s("%Y-%m-%dT%H:%M:%S.%6NZ")
        json.field "level", @level.to_s
        json.field "method_name", @method_name
        json.field "class_name", @class_name
        json.field "file", @file
        json.field "line", @line

        if args = @arguments
          json.field "arguments" do
            args.to_json(json)
          end
        end

        if ret = @return_value
          json.field "return_value", inspect_value(ret)
        end

        if ex = @exception
          json.field "exception" do
            json.object do
              json.field "class", ex.class.to_s
              json.field "message", ex.message
              json.field "backtrace", ex.backtrace?
            end
          end
        end

        json.field "context" do
          @context.to_json(json)
        end

        if dur = @duration
          json.field "duration_ms", dur.total_milliseconds
        end

        json.field "metadata" do
          @metadata.to_json(json)
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

    private def inspect_value(value : _) : String
      case value
      when String, Number, Bool, Nil
        value.inspect
      when JSON::Serializable
        value.to_json
      else
        value.inspect
      end
    end
  end
end
