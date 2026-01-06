module Logit
  # Log severity levels, ordered from least to most severe.
  #
  # Events are only logged if their level is greater than or equal to the
  # backend's configured minimum level. For example, if a backend is set
  # to `Info`, only `Info`, `Warn`, `Error`, and `Fatal` events are logged.
  #
  # ## Level Descriptions
  #
  # - `Trace` - Very detailed debugging information, typically only useful
  #   when diagnosing specific issues
  # - `Debug` - Detailed information useful during development
  # - `Info` - General operational information (default level)
  # - `Warn` - Warning conditions that don't prevent operation but may
  #   indicate problems
  # - `Error` - Error conditions that prevented an operation from completing
  # - `Fatal` - Severe errors that may cause the application to terminate
  #
  # ## Comparison
  #
  # Log levels can be compared using standard comparison operators:
  #
  # ```crystal
  # Logit::LogLevel::Info > Logit::LogLevel::Debug  # => true
  # Logit::LogLevel::Warn >= Logit::LogLevel::Info  # => true
  # ```
  #
  # ## Parsing
  #
  # Log levels can be parsed from strings (case-insensitive):
  #
  # ```crystal
  # level = Logit::LogLevel.parse("debug")  # => LogLevel::Debug
  # level = Logit::LogLevel.parse("INFO")   # => LogLevel::Info
  # ```
  enum LogLevel
    # Very detailed debugging information.
    Trace = 0

    # Detailed information useful during development.
    Debug = 1

    # General operational information (default level).
    Info = 2

    # Warning conditions that may indicate problems.
    Warn = 3

    # Error conditions that prevented an operation.
    Error = 4

    # Severe errors that may terminate the application.
    Fatal = 5

    def to_s(io : IO) : Nil
      case self
      when Trace then io << "trace"
      when Debug then io << "debug"
      when Info  then io << "info"
      when Warn  then io << "warn"
      when Error then io << "error"
      when Fatal then io << "fatal"
      else
        io << "unknown"
      end
    end

    def to_s : String
      case self
      when Trace then "trace"
      when Debug then "debug"
      when Info  then "info"
      when Warn  then "warn"
      when Error then "error"
      when Fatal then "fatal"
      else
        "unknown"
      end
    end

    def <=(other : LogLevel) : Bool
      value <= other.value
    end

    def >=(other : LogLevel) : Bool
      value >= other.value
    end

    def <(other : LogLevel) : Bool
      value < other.value
    end

    def >(other : LogLevel) : Bool
      value > other.value
    end

    # Parses a log level from a string (case-insensitive).
    #
    # Raises `ArgumentError` if the string is not a valid level name.
    def self.parse(str : String) : LogLevel
      case str.downcase
      when "trace" then Trace
      when "debug" then Debug
      when "info"  then Info
      when "warn"  then Warn
      when "error" then Error
      when "fatal" then Fatal
      else
        raise ArgumentError.new("Invalid log level: #{str}")
      end
    end
  end
end
