require "../formatter"
require "../events/event"

module Logit
  class Formatter::JSON < Formatter
    def format(event : Event) : String
      event.to_json
    end
  end
end
