# Global macro finished hook for automatic instrumentation
#
# This macro runs after all types in the file are defined,
# then finds all methods with @[Logit::Log] annotations and
# generates logging wrappers for them.

macro finished
  # Collect all types and methods that need instrumentation
  {% to_gen = [] of NamedTuple(type: TypeNode, method: TypeNode) %}

  # Iterate through all subclasses of Object
  {% for type in Object.all_subclasses %}
    {% for method in type.methods %}
      {% if ann = method.annotation(Logit::Log) %}
        {% to_gen << {type: type, method: method} %}
      {% end %}
    {% end %}
  {% end %}

  # Generate wrappers for each annotated method
  {% for tup in to_gen %}
    {% type = tup[:type] %}
    {% method = tup[:method] %}
    {% ann = method.annotation(Logit::Log) %}

    {% type_name = type.id %}
    {% method_name = method.name.id %}
    {% method_file = method.filename.stringify || __FILE__.stringify %}
    {% method_line = method.line_number || __LINE__ %}
    {% type_string = type.stringify %}
    {% method_name_string = method.name.stringify %}

    # Build args for method signature
    {% args_splat = method.args.splat %}
    {% return_type = method.return_type %}

    # Log options
    {% log_args = ann && ann[:log_args] != nil ? ann[:log_args] : true %}
    {% log_return = ann && ann[:log_return] != nil ? ann[:log_return] : true %}
    {% log_exception = ann && ann[:log_exception] != nil ? ann[:log_exception] : true %}
    {% span_name = ann && ann[:name] ? ann[:name] : method_name_string %}

    # Reopen the class/struct to define wrapper
    {% if type.class? %}
      class {{type_name}}
    {% else %}
      struct {{type_name}}
    {% end %}
      def {{method_name}}({{args_splat}}) {% if return_type %}: {{return_type}}{% end %}
        _span = Logit::Span.new({{span_name}})
        Logit::Span.push(_span)
        _trace_id = _span.trace_id

        {% if log_args && method.args.size > 0 %}
          _span.attributes.set_object("code.arguments",
            {% for arg in method.args %}
              {{arg.name.stringify}}: {{arg.name.id}},
            {% end %}
          )
        {% end %}

        begin
          _result = previous_def(
            {% for arg in method.args %}
              {{arg.name.id}},
            {% end %}
          )

          {% if log_return %}
            _span.attributes.set_any("code.return", _result)
          {% end %}

          _span.end_time = Time.utc
          _event = _span.to_event(
            trace_id: _trace_id,
            level: Logit::LogLevel::Info,
            code_file: {{method_file}},
            code_line: {{method_line}},
            method_name: {{method_name_string}},
            class_name: {{type_string}}
          )
          _event.status = Logit::Status::Ok
          Logit::Tracer.default.emit(_event)

          _result
        rescue ex : ::Exception
          {% if log_exception %}
            _span.exception = Logit::ExceptionInfo.from_exception(ex)
          {% end %}

          _span.end_time = Time.utc
          _event = _span.to_event(
            trace_id: _trace_id,
            level: Logit::LogLevel::Error,
            code_file: {{method_file}},
            code_line: {{method_line}},
            method_name: {{method_name_string}},
            class_name: {{type_string}}
          )
          _event.status = Logit::Status::Error
          Logit::Tracer.default.emit(_event)

          raise ex
        ensure
          Logit::Span.pop
        end
      end
    end
  {% end %}
end
