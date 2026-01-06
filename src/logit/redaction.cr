module Logit
  # Manages sensitive data redaction for log output.
  #
  # Redaction prevents sensitive information (passwords, tokens, API keys, etc.)
  # from appearing in log output. It works at two levels:
  #
  # 1. **Global patterns**: Regex patterns that apply to all instrumented methods
  # 2. **Annotation-level**: Specific argument names listed in `@[Logit::Log(redact: [...])]`
  #
  # ## Global Patterns
  #
  # Add regex patterns that match argument names to be redacted:
  #
  # ```crystal
  # # During configuration
  # Logit.configure do |config|
  #   config.console
  #   config.redact_patterns(/ssn/i, /credit_card/i)
  #   config.redact_common_patterns  # password, token, api_key, etc.
  # end
  #
  # # Or directly via the Redaction class
  # Logit::Redaction.add_pattern(/social_security/i)
  # ```
  #
  # ## Annotation-Level Redaction
  #
  # Specify argument names to redact for a specific method:
  #
  # ```crystal
  # class AuthService
  #   @[Logit::Log(redact: ["password", "pin"])]
  #   def authenticate(username : String, password : String, pin : String) : Bool
  #     # password and pin values will appear as "[REDACTED]" in logs
  #   end
  # end
  # ```
  #
  # ## Common Patterns
  #
  # `enable_common_patterns` adds patterns for commonly sensitive argument names:
  # - password, passwd
  # - secret
  # - token
  # - api_key, apikey
  # - auth
  # - credential
  # - private_key, privatekey
  # - access_key, accesskey
  # - bearer
  class Redaction
    # The replacement value for redacted data.
    REDACTED_VALUE = "[REDACTED]"

    @@patterns : Array(Regex) = [] of Regex
    @@mutex = Mutex.new

    # Adds a regex pattern for argument name matching.
    #
    # Any argument whose name matches this pattern will have its value
    # replaced with `[REDACTED]` in log output.
    #
    # ```crystal
    # Logit::Redaction.add_pattern(/credit_card/i)
    # ```
    def self.add_pattern(pattern : Regex) : Nil
      @@mutex.synchronize do
        @@patterns << pattern unless @@patterns.includes?(pattern)
      end
    end

    # Adds multiple regex patterns at once.
    #
    # ```crystal
    # Logit::Redaction.add_patterns(/ssn/i, /dob/i, /address/i)
    # ```
    def self.add_patterns(*patterns : Regex) : Nil
      @@mutex.synchronize do
        patterns.each do |p|
          @@patterns << p unless @@patterns.includes?(p)
        end
      end
    end

    # Returns a copy of the current global patterns.
    #
    # Thread-safe; returns a duplicate array.
    def self.patterns : Array(Regex)
      @@mutex.synchronize do
        @@patterns.dup
      end
    end

    # Clears all global redaction patterns.
    #
    # Useful for testing or reconfiguration.
    def self.clear_patterns : Nil
      @@mutex.synchronize do
        @@patterns.clear
      end
    end

    # Checks if an argument name matches any global redaction pattern.
    #
    # Returns true if the value should be replaced with `[REDACTED]`.
    def self.should_redact?(arg_name : String) : Bool
      patterns = @@mutex.synchronize { @@patterns.dup }
      patterns.any? { |pattern| pattern.matches?(arg_name) }
    end

    # Alias for `should_redact?` for key-based checks.
    def self.should_redact_key?(key : String) : Bool
      should_redact?(key)
    end

    # Enables a set of commonly-needed security patterns.
    #
    # Adds patterns matching: password, passwd, secret, token, api_key,
    # auth, credential, private_key, access_key, bearer.
    #
    # All patterns are case-insensitive.
    #
    # ```crystal
    # Logit::Redaction.enable_common_patterns
    # ```
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
