require "../backend"
require "../formatter"
require "./buffered"

module Logit
  class Backend::Console < Logit::Backend
    include BufferedIO

    property io : IO = STDOUT

    def initialize(@name = "console", @level = LogLevel::Info, @formatter = Formatter::Human.new)
      super(@name, @level, @formatter)
    end

    def log(event : Event) : Nil
      return unless should_log?(event)

      formatted = @formatter.as(Formatter).format(event)
      buffered_write(@io, formatted)
    end

    def flush : Nil
      flush_buffer(@io)
    end
  end
end
