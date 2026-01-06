module Logit
  # Add key-value pairs to the current logging context
  macro logit_add_context(**kwargs)
    {% if kwargs %}
      Logit::Context.set({{*kwargs}})
    {% end %}
  end

  # Execute a block with additional context that is automatically removed after
  macro logit_with_context(**kwargs, &block)
    {% if kwargs && block %}
      Logit::Context.with_context({{*kwargs}}) do
        {{block.body}}
      end
    {% elsif block %}
      {{block.body}}
    {% end %}
  end
end
