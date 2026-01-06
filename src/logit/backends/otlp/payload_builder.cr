require "json"
require "../../events/event"
require "../../log_level"

module Logit
  class Backend::OTLP < Backend
    # Builds OTLP JSON payloads from Logit events.
    #
    # Converts an array of events to the OTLP/HTTP JSON format for logs.
    # Follows the OpenTelemetry Protocol specification:
    # https://opentelemetry.io/docs/specs/otlp/
    class PayloadBuilder
      # Maps Logit LogLevel to OTLP SeverityNumber.
      # https://opentelemetry.io/docs/specs/otel/logs/data-model/#field-severitynumber
      SEVERITY_MAP = {
        LogLevel::Trace => 1,  # TRACE
        LogLevel::Debug => 5,  # DEBUG
        LogLevel::Info  => 9,  # INFO
        LogLevel::Warn  => 13, # WARN
        LogLevel::Error => 17, # ERROR
        LogLevel::Fatal => 21, # FATAL
      }

      @resource_attributes : Hash(String, String)
      @scope_name : String
      @scope_version : String

      def initialize(
        @resource_attributes : Hash(String, String),
        @scope_name : String,
        @scope_version : String
      )
      end

      # Builds an OTLP JSON payload from an array of events.
      #
      # Returns a JSON string ready to be sent to an OTLP collector.
      def build(events : Array(Event)) : String
        String.build do |io|
          JSON.build(io) do |json|
            json.object do
              json.field "resourceLogs" do
                json.array do
                  json.object do
                    build_resource(json)
                    json.field "scopeLogs" do
                      json.array do
                        json.object do
                          build_scope(json)
                          json.field "logRecords" do
                            json.array do
                              events.each { |event| build_log_record(json, event) }
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      private def build_resource(json : JSON::Builder) : Nil
        json.field "resource" do
          json.object do
            json.field "attributes" do
              json.array do
                @resource_attributes.each do |key, value|
                  build_string_kv(json, key, value)
                end
              end
            end
          end
        end
      end

      private def build_scope(json : JSON::Builder) : Nil
        json.field "scope" do
          json.object do
            json.field "name", @scope_name
            json.field "version", @scope_version
          end
        end
      end

      private def build_log_record(json : JSON::Builder, event : Event) : Nil
        json.object do
          # Timestamps in nanoseconds as string (OTLP uses fixed64 in proto, string in JSON)
          timestamp_ns = (event.timestamp.to_unix_ns).to_s
          json.field "timeUnixNano", timestamp_ns
          json.field "observedTimeUnixNano", timestamp_ns

          # Severity
          json.field "severityNumber", SEVERITY_MAP[event.level]
          json.field "severityText", event.level.to_s.upcase

          # Body - use the span/event name as the log message body
          json.field "body" do
            json.object do
              json.field "stringValue", event.name
            end
          end

          # Trace context (hex strings, uppercase per OTLP spec recommendation)
          json.field "traceId", event.trace_id.upcase
          json.field "spanId", event.span_id.upcase

          # Flags: 1 = TRACE_FLAGS_SAMPLED
          json.field "flags", 1

          # Attributes
          json.field "attributes" do
            json.array do
              # Code location attributes (OpenTelemetry semantic conventions)
              build_string_kv(json, "code.function", event.method_name)
              build_string_kv(json, "code.namespace", event.class_name)
              build_string_kv(json, "code.filepath", event.code_file)
              build_int_kv(json, "code.lineno", event.code_line.to_i64)

              # Logit-specific attributes
              build_int_kv(json, "logit.duration_ms", event.duration_ms)
              build_string_kv(json, "logit.status", event.status.to_s)

              # Parent span ID if present
              if parent_id = event.parent_span_id
                build_string_kv(json, "logit.parent_span_id", parent_id)
              end

              # Exception info if present
              if ex = event.exception
                build_string_kv(json, "exception.type", ex.type)
                build_string_kv(json, "exception.message", ex.message)
                if stacktrace = ex.stacktrace
                  build_string_kv(json, "exception.stacktrace", stacktrace.join("\n"))
                end
              end

              # User-defined attributes from the event
              event.attributes.values.each do |key, value|
                build_any_kv(json, key, value)
              end
            end
          end
        end
      end

      # Builds a KeyValue with string value
      private def build_string_kv(json : JSON::Builder, key : String, value : String) : Nil
        json.object do
          json.field "key", key
          json.field "value" do
            json.object do
              json.field "stringValue", value
            end
          end
        end
      end

      # Builds a KeyValue with int64 value (as string per OTLP JSON spec)
      private def build_int_kv(json : JSON::Builder, key : String, value : Int64) : Nil
        json.object do
          json.field "key", key
          json.field "value" do
            json.object do
              json.field "intValue", value.to_s
            end
          end
        end
      end

      # Builds a KeyValue with double value
      private def build_double_kv(json : JSON::Builder, key : String, value : Float64) : Nil
        json.object do
          json.field "key", key
          json.field "value" do
            json.object do
              json.field "doubleValue", value
            end
          end
        end
      end

      # Builds a KeyValue with bool value
      private def build_bool_kv(json : JSON::Builder, key : String, value : Bool) : Nil
        json.object do
          json.field "key", key
          json.field "value" do
            json.object do
              json.field "boolValue", value
            end
          end
        end
      end

      # Builds a KeyValue from a JSON::Any value (determines type at runtime)
      private def build_any_kv(json : JSON::Builder, key : String, value : JSON::Any) : Nil
        json.object do
          json.field "key", key
          json.field "value" do
            build_any_value(json, value)
          end
        end
      end

      # Builds an AnyValue from a JSON::Any
      private def build_any_value(json : JSON::Builder, value : JSON::Any) : Nil
        json.object do
          case raw = value.raw
          when String
            json.field "stringValue", raw
          when Int64
            json.field "intValue", raw.to_s
          when Float64
            json.field "doubleValue", raw
          when Bool
            json.field "boolValue", raw
          when Array
            json.field "arrayValue" do
              json.object do
                json.field "values" do
                  json.array do
                    raw.each do |item|
                      build_any_value(json, item.as(JSON::Any))
                    end
                  end
                end
              end
            end
          when Hash
            json.field "kvlistValue" do
              json.object do
                json.field "values" do
                  json.array do
                    raw.each do |k, v|
                      build_any_kv(json, k.to_s, v.as(JSON::Any))
                    end
                  end
                end
              end
            end
          when Nil
            # OTLP doesn't have a null type, use empty string
            json.field "stringValue", ""
          end
        end
      end
    end
  end
end
