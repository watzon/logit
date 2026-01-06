module Logit
  # Handles sensitive data redaction for logging
  # Supports both annotation-level and global pattern-based redaction
  class Redaction
    REDACTED_VALUE = "[REDACTED]"

    # Thread-safe storage for global patterns
    @@patterns : Array(Regex) = [] of Regex
    @@mutex = Mutex.new

    # Add a single global redaction pattern
    def self.add_pattern(pattern : Regex) : Nil
      @@mutex.synchronize do
        @@patterns << pattern unless @@patterns.includes?(pattern)
      end
    end

    # Add multiple global redaction patterns
    def self.add_patterns(*patterns : Regex) : Nil
      @@mutex.synchronize do
        patterns.each do |p|
          @@patterns << p unless @@patterns.includes?(p)
        end
      end
    end

    # Get a copy of current patterns (thread-safe)
    def self.patterns : Array(Regex)
      @@mutex.synchronize do
        @@patterns.dup
      end
    end

    # Clear all global patterns
    def self.clear_patterns : Nil
      @@mutex.synchronize do
        @@patterns.clear
      end
    end

    # Check if an argument name should be redacted based on global patterns
    def self.should_redact?(arg_name : String) : Bool
      patterns = @@mutex.synchronize { @@patterns.dup }
      patterns.any? { |pattern| pattern.matches?(arg_name) }
    end

    # Check if a value should be redacted (for key-based checks)
    def self.should_redact_key?(key : String) : Bool
      should_redact?(key)
    end

    # Convenience method to apply common security patterns
    # Users can call this to enable sensible defaults
    def self.enable_common_patterns : Nil
      add_patterns(
        /password/i,
        /passwd/i,
        /secret/i,
        /token/i,
        /api_?key/i,
        /auth/i,
        /credential/i,
        /private_?key/i,
        /access_?key/i,
        /bearer/i
      )
    end
  end
end
