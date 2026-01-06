require "../registry"
require "./wrapper"

module Logit
  # Include this module to enable logging wrapper generation
  #
  # IMPORTANT: You MUST call `Logit.setup_instrumentation(YourClassName)` at the END
  # of your class definition, AFTER all methods have been defined.
  #
  # Example:
  # ```
  # class MyService
  #   include Logit::Instrumentation
  #
  #   @[Logit::Log]
  #   def my_method
  #     # ...
  #   end
  #
  #   # MUST be called AFTER all method definitions
  #   Logit.setup_instrumentation(MyService)
  # end
  # ```
  #
  # Why is this required?
  # Crystal's macro system processes code linearly. When `include Logit::Instrumentation`
  # is encountered, any `macro included` hooks run immediately, before methods are defined.
  # We need the setup to happen AFTER all methods are defined, which is why you must
  # explicitly call `Logit.setup_instrumentation` at the end of the class.
  #
  # Note: While Crystal has a `macro finished` hook that runs after a class body is
  # complete, it cannot be automatically injected via module inclusion due to macro
  # scoping limitations. This manual call is the cleanest solution available.
  module Instrumentation
    # Marker module - the actual work is done by setup_instrumentation
  end
end
