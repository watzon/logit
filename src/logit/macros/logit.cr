# Module to hold the setup macro
module Logit
  # Setup macro - place at the bottom of your main file
  # This finds all types with @[Logit::Log] annotations and generates wrapper methods
  macro setup
    {% for type in Object.all_subclasses %}
      {% for method in type.methods %}
        {% if ann = method.annotation(Logit::Log) %}
          # Generate wrapper method by reopening the class
          class {{type.id}}
            def {{method.name.id}}(
              {% for arg in method.args %}
                {{arg.name.id}}{% if !arg.restriction.is_a?(Nop) %} : {{arg.restriction}}{% end %},
              {% end %}
              {% if method.splat_index %}
                *{{method.args[method.splat_index].name.id}}
              {% end %}
              {% if method.double_splat && method.double_splat.is_a?(Arg) %}
                **{{method.double_splat.name.id}}
              {% end %}
              {% if method.block_arg && method.block_arg.is_a?(Arg) %}
                &{{method.block_arg.name.id}}
              {% end %}
            ) {% if method.return_type && !method.return_type.is_a?(Nop) %}: {{method.return_type}}{% end %}
              {% log_level = ann && ann[:level] ? ann[:level] : "Logit::LogLevel::Info".id %}
              {% log_args = ann && ann[:log_args] != nil ? ann[:log_args] : true %}
              {% log_return = ann && ann[:log_return] != nil ? ann[:log_return] : true %}
              {% log_exception = ann && ann[:log_exception] != nil ? ann[:log_exception] : true %}

              _logit_entry = Logit::LogEntry.new(
                timestamp: Time.utc,
                level: {{log_level}},
                method_name: {{method.name.stringify}},
                class_name: {{type.name.stringify}},
                file: "unknown",
                line: 0,
                {% if log_args && method.args.size > 0 %}
                arguments: {
                  {% for arg in method.args %}
                    {{arg.name.stringify}} => {{arg.name.id}}.to_s,
                  {% end %}
                },
                {% else %}
                arguments: nil,
                {% end %}
                context: Logit::Context.current
              )

              Logit::Logger.dispatch(_logit_entry, :before)

              begin
                result = previous_def(
                  {% for arg in method.args %}
                    {{arg.name.id}},
                  {% end %}
                  {% if method.splat_index %}
                    *{{method.args[method.splat_index].name.id}}
                  {% end %}
                  {% if method.double_splat && method.double_splat.is_a?(Arg) %}
                    **{{method.double_splat.name.id}}
                  {% end %}
                  {% if method.block_arg && method.block_arg.is_a?(Arg) %}
                    &{{method.block_arg.name.id}}
                  {% end %}
                )

                {% if log_return %}
                _logit_entry.return_value = result.to_s
                {% end %}
                _logit_entry.duration = Time.utc - _logit_entry.timestamp
                # Update context to include any context added during method execution
                _logit_entry.context = Logit::Context.current
                Logit::Logger.dispatch(_logit_entry, :after)
                result
              rescue ex : Exception
                {% if log_exception %}
                _logit_entry.exception = ex
                _logit_entry.level = Logit::LogLevel::Error
                # Update context to include any context added during method execution
                _logit_entry.context = Logit::Context.current
                {% end %}
                Logit::Logger.dispatch(_logit_entry, :exception)
                raise ex
              ensure
                # Clear method-local context after the method completes
                Logit::Context.clear_method
              end
            end
          end
        {% end %}
      {% end %}
    {% end %}
  end
end

# Keep Logit::Magic for backwards compatibility
module Logit::Magic
  macro included
    {% for method in @type.methods %}
      {% if ann = method.annotation(Logit::Log) %}
        # Generate wrapper method with preserved signature
        def {{method.name.id}}(
          {% for arg in method.args %}
            {{arg.external_name.id}} : {{arg.restriction}}{% if !arg.restriction.is_a?(Nop) %},{% end %}
          {% end %}
          {% if method.splat_index %}
            *{{method.args[method.splat_index].external_name.id}} : {{method.args[method.splat_index].restriction}}
          {% end %}
          {% if method.double_splat && method.double_splat.is_a?(Arg) %}
            **{{method.double_splat.external_name.id}}
          {% end %}
          {% if method.block_arg && method.block_arg.is_a?(Arg) %}
            &{{method.block_arg.external_name.id}} : {{method.block_arg.restriction}}
          {% end %}
        ) {% if method.return_type && !method.return_type.is_a?(Nop) %}: {{method.return_type}}{% end %}
          # Create log entry
          {% log_level = ann && ann[:level] ? ann[:level] : "LogLevel::Info".id %}
          {% log_args = ann && ann[:log_args] != nil ? ann[:log_args] : true %}
          {% log_return = ann && ann[:log_return] != nil ? ann[:log_return] : true %}
          {% log_exception = ann && ann[:log_exception] != nil ? ann[:log_exception] : true %}

          _logit_entry = Logit::LogEntry.new(
            timestamp: Time.utc,
            level: {{log_level}},
            method_name: {{method.name.stringify}},
            class_name: {{@type.name.stringify}},
            file: {{method.file.stringify}},
            line: {{method.line}},
            {% if log_args %}
            arguments: {
              {% for arg in method.args %}
                {{arg.external_name.stringify}} => {{arg.external_name.id}},
              {% end %}
            },
            {% end %}
            context: Logit::Context.current
          )

          Logit::Logger.dispatch(_logit_entry, :before)

          begin
            # Call original method via super
            result = super(
              {% for arg in method.args %}
                {{arg.external_name.id}},
              {% end %}
              {% if method.splat_index %}
                *{{method.args[method.splat_index].external_name.id}}
              {% end %}
              {% if method.double_splat && method.double_splat.is_a?(Arg) %}
                **{{method.double_splat.external_name.id}}
              {% end %}
              {% if method.block_arg && method.block_arg.is_a?(Arg) %}
                &{{method.block_arg.external_name.id}}
              {% end %}
            )

            {% if log_return %}
            _logit_entry.return_value = result
            {% end %}
            _logit_entry.duration = Time.utc - _logit_entry.timestamp
            Logit::Logger.dispatch(_logit_entry, :after)
            result
          rescue ex : Exception
            {% if log_exception %}
            _logit_entry.exception = ex
            {% end %}
            Logit::Logger.dispatch(_logit_entry, :exception)
            raise ex
          end
        end
      {% end %}
    {% end %}
  end
end
