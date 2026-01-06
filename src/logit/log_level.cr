module Logit
  enum LogLevel
    Trace = 0
    Debug = 1
    Info  = 2
    Warn  = 3
    Error = 4
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
