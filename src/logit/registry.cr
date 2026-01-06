require "./log_level"
require "./macros/wrapper"

module Logit
  # Compile-time registry for methods with @Log annotation
  # This eliminates the need for Object.all_subclasses scan

  # Annotation to mark methods for logging
  annotation Log
  end

  # Setup macro to be called at the END of a class definition
  # This generates wrapper methods for all @Log annotated methods
  macro setup_instrumentation(type_name)
    # Iterate over methods and generate wrappers for those with @Log annotation
    {% for method in type_name.resolve.methods %}
      {% if ann = method.annotation(Logit::Log) %}

        # Build arg info
        {% args_info = [] of NamedTuple(name: String, type: String) %}
        {% for arg in method.args %}
          {% arg_info = {name: arg.name.stringify, type: arg.restriction.is_a?(Nop) ? "".id : arg.restriction.stringify} %}
          {% args_info << arg_info %}
        {% end %}

        # Get file/line from method if available, otherwise use __FILE__/__LINE__
        {% method_file = method.filename.stringify || __FILE__.stringify %}
        {% method_line = method.line_number || __LINE__ %}

        # Generate wrapper
        {% if method.args.empty? %}
          Logit::Macros.wrapper(
            {{type_name.id.stringify}},
            {{method.name}},
            {{method_file}},
            {{method_line}},
            [] of NamedTuple(name: String, type: String),
            {{method.return_type.stringify}},
            {{ann}}
          )
        {% else %}
          Logit::Macros.wrapper(
            {{type_name.id.stringify}},
            {{method.name}},
            {{method_file}},
            {{method_line}},
            {{args_info}},
            {{method.return_type.stringify}},
            {{ann}}
          )
        {% end %}
      {% end %}
    {% end %}
  end
end
