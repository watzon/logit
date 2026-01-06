# Logit - The Perfect Crystal Logging Library
#
# Annotation-based logging with OpenTelemetry support, wide events, and type-safe structured logging.

module Logit
  # Annotation to mark methods for logging
  annotation Log
  end
end

require "./log_level"
require "./events/attributes"
require "./events/event"
require "./utils/id_generator"
require "./tracing/span"
require "./tracing/tracer"
require "./backend"
require "./formatter"
require "./formatters/human"
require "./formatters/json"
require "./backends/console"
require "./backends/file"
require "./redaction"
require "./context"
require "./config"
require "./macros/register"
