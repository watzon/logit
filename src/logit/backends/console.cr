require "../backend"
require "../formatter"
require "./buffered"

module Logit
  # Backend that writes log events to the console (STDOUT).
  #
  # Uses the `Formatter::Human` formatter by default, which produces colorized,
  # human-readable output suitable for development and debugging.
  #
  # ## Basic Usage
  #
  # ```crystal
  # Logit.configure do |config|
  #   config.console(level: Logit::LogLevel::Debug)
  # end
  # ```
  #
  # ## Custom Configuration
  #
  # ```crystal
  # # Use JSON formatter for console output
  # Logit.configure do |config|
  #   config.console(
  #     level: Logit::LogLevel::Info,
  #     formatter: Logit::Formatter::JSON.new
  #   )
  # end
  # ```
  #
  # ## Output Example (Human formatter)
  #
  # ```
  # 10:30:45.123 INFO  UserService#find_user (2ms) → User{id: 42}  user_service.cr:15
  #     args: id=42
  # ```
  class Backend::Console < Logit::Backend
    include BufferedIO

    # The IO to write to (defaults to STDOUT).
    property io : IO = STDOUT

    # Creates a new console backend.
    #
    # - *name*: Backend name for identification (default: "console")
    # - *level*: Minimum log level (default: Info)
    # - *formatter*: Output formatter (default: Human)
    def initialize(@name = "console", @level = LogLevel::Info, @formatter = Formatter::Human.new)
      super(@name, @level, @formatter)
    end

    # Logs an event to the console.
    def log(event : Event) : Nil
      return unless should_log?(event)

      formatted = @formatter.as(Formatter).format(event)
      buffered_write(@io, formatted)
    end

    # Flushes the output buffer.
    def flush : Nil
      flush_buffer(@io)
    end
  end
end
