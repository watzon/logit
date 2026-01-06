require "./log_level"
require "./pattern_matcher"

module Logit
  # Represents a binding between a namespace pattern and a log level
  struct NamespaceBinding
    property pattern : String
    property level : LogLevel

    def initialize(@pattern : String, @level : LogLevel)
      validate_pattern!
    end

    # Check if a given namespace matches this pattern
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
