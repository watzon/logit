require "../backend"
require "../formatter"

module Logit
  class Backend::Console < Logit::Backend
    property io : IO = STDOUT

    def initialize(@name = "console", @level = LogLevel::Info,
                   @formatter = Formatter::Human.new)
      super(@name, @level, @formatter)
    end

    def log(event : Event) : Nil
      return unless should_log?(event)

      @io << @formatter.as(Formatter).format(event) << "\n"
      @io.flush
    end

    def flush : Nil
      @io.flush
    end
  end
end
