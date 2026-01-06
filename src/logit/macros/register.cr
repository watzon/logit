require "../registry"
require "./wrapper"

module Logit
  # Marker module for documentation purposes
  #
  # Including this module is optional - the global `macro finished` hook
  # will automatically instrument all methods annotated with `@[Logit::Log]`.
  #
  # You can include this module for documentation clarity, but it's not required:
  #
  # ```
  # class MyService
  #   include Logit::Instrumentation  # Optional, for documentation
  #
  #   @[Logit::Log]
  #   def my_method
  #     # ...
  #   end
  # end
  # ```
  module Instrumentation
    # Marker module - instrumentation is handled by global macro finished
  end
end
