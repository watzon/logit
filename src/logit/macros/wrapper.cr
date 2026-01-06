require "../tracing/span"
require "../tracing/tracer"
require "../utils/id_generator"
require "../events/event"
require "json"

module Logit
  module Macros
    macro wrapper(type_name, method_name, file, line, args, return_type, ann)
      # Generate wrapper with preserved source location
      def {{method_name.id}}(
        {% for arg in args %}
          {{arg[:name].id}} : {{arg[:type].id}},
        {% end %}
        {% if block_arg = args.find { |a| a[:block] } %}
          &{{block_arg[:name].id}} : {{block_arg[:type].id}}
        {% end %}
      ) {% if return_type && return_type != "" %}: {{return_type.id}}{% end %}
        # Extract annotation options
        # TODO: Support custom levels from annotation
        {% level_const = "Logit::LogLevel::Info" %}
        {% log_args = ann && ann[:log_args] != nil ? ann[:log_args] : true %}
        {% log_return = ann && ann[:log_return] != nil ? ann[:log_return] : true %}
        {% log_exception = ann && ann[:log_exception] != nil ? ann[:log_exception] : true %}
        {% span_name = ann && ann[:name] ? ann[:name] : method_name.stringify %}

        # Create and push span (trace_id is generated/inherited by Span)
        _span = Logit::Span.new({{span_name}})
        Logit::Span.push(_span)

        # Get trace_id from the span
        _trace_id = _span.trace_id

        # Log arguments if enabled
        {% if log_args && args.size > 0 %}
          _span.attributes.set_object("code.arguments",
            {% for arg in args %}
              {% unless arg[:block] %}
                {{arg[:name].stringify}}: {{arg[:name].id}},
              {% end %}
            {% end %}
          )
        {% end %}

        begin
          # Call original method via previous_def
          _result = previous_def(
            {% for arg in args %}
              {% unless arg[:block] %}
                {{arg[:name].id}},
              {% end %}
            {% end %}
            {% if block_arg = args.find { |a| a[:block] } %}
              &{{block_arg[:name].id}}
            {% end %}
          )

          # Log return value if enabled
          {% if log_return %}
            _span.attributes.set_any("code.return", _result)
          {% end %}

          # Mark span as complete
          _span.end_time = Time.utc

          # Create event and emit
          _event = _span.to_event(
            trace_id: _trace_id,
            level: Logit::LogLevel::Info,
            code_file: {{file.stringify}},
            code_line: {{line}},
            method_name: {{method_name.stringify}},
            class_name: {{type_name.stringify}}
          )
          _event.status = Logit::Status::Ok
          Logit::Tracer.default.emit(_event)

          _result
        rescue ex : ::Exception
          # Handle exception
          {% if log_exception %}
            _span.exception = Logit::ExceptionInfo.from_exception(ex)
          {% end %}

          _span.end_time = Time.utc

          _event = _span.to_event(
            trace_id: _trace_id,
            level: Logit::LogLevel::Error,
            code_file: {{file.stringify}},
            code_line: {{line}},
            method_name: {{method_name.stringify}},
            class_name: {{type_name.stringify}}
          )
          _event.status = Logit::Status::Error
          Logit::Tracer.default.emit(_event)

          raise ex
        ensure
          # Always pop span
          Logit::Span.pop
        end
      end
    end
  end
end
