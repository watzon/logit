require "./log_level"
require "./pattern_matcher"

module Logit
  # Binds a namespace pattern to a log level for filtering.
  #
  # Namespace bindings allow different log levels for different parts of your
  # codebase. They are created via `Backend#bind` or `Config#bind`.
  #
  # ## Pattern Syntax
  #
  # Patterns use Crystal's `::` namespace separator with wildcards:
  #
  # - `MyApp::*` - Matches classes directly in `MyApp` (e.g., `MyApp::User`)
  # - `MyApp::**` - Matches classes in `MyApp` and all nested namespaces
  # - `MyApp::Database::Query` - Matches exactly this class
  #
  # ## Examples
  #
  # ```crystal
  # Logit.configure do |config|
  #   console = config.console(level: Logit::LogLevel::Info)
  #
  #   # Reduce noise from database classes
  #   config.bind("MyApp::Database::*", Logit::LogLevel::Warn, console)
  #
  #   # But keep verbose logging for query builder
  #   config.bind("MyApp::Database::QueryBuilder", Logit::LogLevel::Debug, console)
  # end
  # ```
  struct NamespaceBinding
    # The namespace pattern (e.g., "MyApp::Database::*").
    property pattern : String

    # The log level for namespaces matching this pattern.
    property level : LogLevel

    # Creates a new binding. Raises if the pattern is invalid.
    def initialize(@pattern : String, @level : LogLevel)
      validate_pattern!
    end

    # Checks if a namespace matches this pattern.
    def matches?(namespace : String) : Bool
      PatternMatcher.match?(namespace, @pattern)
    end

    private def validate_pattern!
      # Ensure pattern is not empty
      if @pattern.empty?
        raise ArgumentError.new("Pattern cannot be empty")
      end

      # Ensure pattern uses :: separator
      unless @pattern.includes?("::")
        raise ArgumentError.new("Pattern must use '::' separator: #{@pattern}")
      end

      # Ensure no consecutive ::: (invalid)
      if @pattern.includes?(":::")
        raise ArgumentError.new("Pattern cannot contain ':::': #{@pattern}")
      end
    end
  end
end
