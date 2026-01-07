require "../backend"

module Logit
  # Null backend that discards all log events.
  #
  # This is the default backend when Logit is first required, ensuring that
  # libraries using Logit don't impose logging on applications. Applications
  # can replace this with real backends by calling `Logit.configure`.
  #
  # Inspired by Python's `logging.NullHandler` pattern, this allows libraries
  # to use Logit for instrumentation without producing any output unless the
  # consuming application explicitly enables it.
  #
  # ## Usage in Libraries
  #
  # Libraries can use Logit freely - events will be discarded by default:
  #
  # ```crystal
  # # In your library shard
  # require "logit"
  #
  # module MyLib
  #   def self.process(data : String) : String
  #     span = Logit::Span.new("mylib.process")
  #     span.attributes.set("input_size", data.size)
  #     span.end_time = Time.utc
  #
  #     # This will be discarded unless app configures a real backend
  #     Logit::Tracer.default.emit(span.to_event(
  #       trace_id: span.trace_id,
  #       level: Logit::LogLevel::Info,
  #       code_file: __FILE__,
  #       code_line: __LINE__,
  #       method_name: "process",
  #       class_name: "MyLib"
  #     ))
  #
  #     data.upcase
  #   end
  # end
  # ```
  #
  # ## Enabling Library Logs in Applications
  #
  # Applications can enable logging from libraries by configuring Logit:
  #
  # ```crystal
  # require "logit"
  #
  # # Configure Logit to enable output
  # Logit.configure do |config|
  #   config.console(Logit::LogLevel::Debug)
  #   config.bind "MyLib::**", LogLevel::Debug, _
  # end
  #
  # require "my-lib"
  #
  # # Now library logs will appear
  # MyLib.process("hello")  # -> [DEBUG] ... mylib.process ...
  # ```
  class Backend::Null < Backend
    def initialize
      super("null", LogLevel::Fatal) # Highest level = logs nothing
    end

    # No-op - discards all events.
    def log(event : Event) : Nil
      # Intentionally empty
    end

    # Always returns false - never logs anything.
    def should_log?(event : Event) : Bool
      false
    end

    # Always returns false - never logs anything at any level.
    def should_log_level?(level : LogLevel, namespace : String) : Bool
      false
    end

    # No-op - nothing to flush.
    def flush : Nil
    end

    # No-op - nothing to close.
    def close : Nil
    end
  end
end
