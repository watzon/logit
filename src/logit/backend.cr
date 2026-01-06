require "./events/event"
require "./log_level"

module Logit
  abstract class Backend
    property name : String
    property level : LogLevel
    property formatter : Formatter?

    def initialize(@name, @level = LogLevel::Info, @formatter = nil)
    end

    # Log event
    abstract def log(event : Event) : Nil

    # Flush buffered data (default: no-op)
    def flush : Nil
    end

    # Close backend and release resources (default: no-op)
    def close : Nil
    end

    # Check if backend should log this event
    def should_log?(event : Event) : Bool
      event.level >= @level
    end
  end
end
