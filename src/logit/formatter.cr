require "./events/event"

module Logit
  abstract class Formatter
    abstract def format(event : Event) : String
  end
end
