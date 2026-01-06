require "./events/event"
require "./log_level"
require "./namespace_binding"

module Logit
  abstract class Backend
    property name : String
    property level : LogLevel
    property formatter : Formatter?
    property bindings : Array(NamespaceBinding)

    def initialize(@name, @level = LogLevel::Info, @formatter = nil)
      @bindings = [] of NamespaceBinding
    end

    # Log event
    abstract def log(event : Event) : Nil

    # Flush buffered data (default: no-op)
    def flush : Nil
    end

    # Close backend and release resources (default: no-op)
    def close : Nil
    end

    # Bind a namespace pattern to a specific level for this backend
    def bind(pattern : String, level : LogLevel) : Nil
      binding = NamespaceBinding.new(pattern, level)

      # Remove any existing binding for the same pattern
      @bindings.reject! { |b| b.pattern == pattern }

      # Add new binding
      @bindings << binding
    end

    # Check if backend should log this event
    def should_log?(event : Event) : Bool
      effective_level = get_level_for_namespace(event.class_name)
      event.level >= effective_level
    end

    # Check if this backend would log at a given level for a namespace
    # Used for early filtering before creating spans/events
    def should_log_level?(level : LogLevel, namespace : String) : Bool
      effective_level = get_level_for_namespace(namespace)
      level >= effective_level
    end

    # Get the effective log level for a given namespace
    # Returns the most specific binding level, or default level if no match
    private def get_level_for_namespace(namespace : String) : LogLevel
      # Find all matching bindings
      matching_bindings = @bindings.select { |b| b.matches?(namespace) }

      if matching_bindings.empty?
        # No match, use default level
        @level
      else
        # Return the level from the most specific (longest) pattern
        # This ensures more specific patterns take precedence
        most_specific = matching_bindings.max_by { |b| b.pattern.split("::").size }
        most_specific.level
      end
    end
  end
end
