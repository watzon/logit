require "./events/event"
require "./log_level"
require "./namespace_binding"

module Logit
  # Abstract base class for log output destinations.
  #
  # Backends receive log events and write them to their destination (console,
  # file, network, etc.). Each backend has:
  # - A minimum log level (events below this level are ignored)
  # - An optional formatter (converts events to strings)
  # - Namespace bindings (per-namespace level overrides)
  #
  # ## Built-in Backends
  #
  # - `Backend::Console` - Writes to STDOUT with colorized human-readable output
  # - `Backend::File` - Writes to a file with JSON output
  #
  # ## Creating a Custom Backend
  #
  # Subclass `Backend` and implement the `log` method:
  #
  # ```crystal
  # class MyBackend < Logit::Backend
  #   def initialize(name = "my_backend", level = Logit::LogLevel::Info)
  #     super(name, level)
  #   end
  #
  #   def log(event : Logit::Event) : Nil
  #     return unless should_log?(event)
  #
  #     # Format and output the event
  #     output = @formatter.try(&.format(event)) || event.to_json
  #     # ... write output to your destination
  #   end
  #
  #   def flush : Nil
  #     # Flush any buffered data
  #   end
  #
  #   def close : Nil
  #     # Release resources
  #   end
  # end
  # ```
  #
  # ## Namespace Bindings
  #
  # Backends can have different log levels for different namespaces:
  #
  # ```crystal
  # backend = Logit::Backend::Console.new
  #
  # # Default level is Info, but Database classes log at Warn
  # backend.bind("MyApp::Database::*", Logit::LogLevel::Warn)
  #
  # # Except QueryBuilder, which logs at Debug
  # backend.bind("MyApp::Database::QueryBuilder", Logit::LogLevel::Debug)
  # ```
  abstract class Backend
    # Unique name for this backend (used for removal and identification).
    property name : String

    # Minimum log level for this backend.
    property level : LogLevel

    # Formatter used to convert events to strings.
    property formatter : Formatter?

    # Namespace-specific log level bindings.
    property bindings : Array(NamespaceBinding)

    # Creates a new backend with the given name and level.
    def initialize(@name, @level = LogLevel::Info, @formatter = nil)
      @bindings = [] of NamespaceBinding
    end

    # Logs an event to this backend.
    #
    # Implementations should check `should_log?(event)` before processing.
    abstract def log(event : Event) : Nil

    # Flushes any buffered data.
    #
    # Override this if your backend buffers output. The default implementation
    # is a no-op.
    def flush : Nil
    end

    # Closes the backend and releases resources.
    #
    # Override this if your backend holds resources (file handles, connections).
    # The default implementation is a no-op.
    def close : Nil
    end

    # Binds a namespace pattern to a specific log level.
    #
    # Events from classes matching the pattern will use this level instead
    # of the backend's default level. More specific patterns take precedence.
    #
    # Pattern syntax:
    # - `MyApp::*` - matches classes directly in MyApp
    # - `MyApp::**` - matches classes in MyApp and all nested namespaces
    # - `MyApp::Database::Query` - matches exactly this class
    def bind(pattern : String, level : LogLevel) : Nil
      binding = NamespaceBinding.new(pattern, level)

      # Remove any existing binding for the same pattern
      @bindings.reject! { |b| b.pattern == pattern }

      # Add new binding
      @bindings << binding
    end

    # Checks if this backend should log the given event.
    #
    # Takes into account both the backend's level and any namespace bindings.
    def should_log?(event : Event) : Bool
      effective_level = get_level_for_namespace(event.class_name)
      event.level >= effective_level
    end

    # Checks if this backend would log at the given level for a namespace.
    #
    # Used for early filtering before creating spans/events.
    def should_log_level?(level : LogLevel, namespace : String) : Bool
      effective_level = get_level_for_namespace(namespace)
      level >= effective_level
    end

    # Returns the effective log level for a namespace.
    #
    # Checks namespace bindings from most specific to least specific,
    # falling back to the backend's default level if no binding matches.
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
