require "../backend"

module Logit
  class Backend::File < Logit::Backend
    @path : String
    @file : ::File

    def initialize(@path, @name = "file", @level = LogLevel::Info)
      super(@name, @level)
      @file = ::File.open(@path, "a")
    end

    def log(event : Event) : Nil
      return unless should_log?(event)

      @file << event.to_json << "\n"
      @file.flush
    end

    def close : Nil
      @file.close
    end
  end
end
