# Logit - Annotation-based logging with OpenTelemetry support for Crystal.
#
# Logit provides automatic method instrumentation through annotations, structured
# logging with wide events, and full OpenTelemetry compatibility. Simply annotate
# methods with `@[Logit::Log]` and Logit handles the rest.
#
# ## Quick Start
#
# ```crystal
# require "logit"
#
# # Configure Logit (optional - defaults to console output)
# Logit.configure do |config|
#   config.console(level: Logit::LogLevel::Debug)
# end
#
# class MyService
#   @[Logit::Log]
#   def process(data : String) : String
#     data.upcase
#   end
# end
# ```
#
# ## Annotation Options
#
# The `@[Logit::Log]` annotation supports the following options:
#
# - `log_args` (Bool) - Whether to log method arguments (default: true)
# - `log_return` (Bool) - Whether to log return values (default: true)
# - `log_exception` (Bool) - Whether to log exceptions (default: true)
# - `name` (String) - Custom span name (default: method name)
# - `level` (LogLevel) - Log level for this method (default: Info)
# - `redact` (Array(String)) - Argument names to redact from logs
#
# ## Key Features
#
# - **Automatic instrumentation**: No manual log calls needed
# - **OpenTelemetry semantics**: Trace IDs, span IDs, and semantic attributes
# - **Fiber-aware context**: Spans are tracked per-fiber for safe concurrency
# - **Flexible backends**: Console, file, or custom backends
# - **Namespace filtering**: Control log levels per namespace pattern
# - **Redaction support**: Automatically redact sensitive data
#
# See `Logit.configure` for configuration options and `Logit::Backend` for
# available output backends.
module Logit
  # Annotation to mark methods for automatic logging instrumentation.
  #
  # When a method is annotated with `@[Logit::Log]`, Logit automatically:
  # - Creates a span when the method is called
  # - Logs method arguments (unless disabled)
  # - Logs the return value (unless disabled)
  # - Logs any exceptions (unless disabled)
  # - Tracks timing/duration
  # - Maintains trace context across nested calls
  #
  # ## Basic Usage
  #
  # ```crystal
  # class UserService
  #   @[Logit::Log]
  #   def find_user(id : Int32) : User?
  #     User.find(id)
  #   end
  # end
  # ```
  #
  # ## With Options
  #
  # ```crystal
  # class AuthService
  #   @[Logit::Log(log_args: false, redact: ["password"])]
  #   def authenticate(username : String, password : String) : Bool
  #     # password won't be logged
  #   end
  #
  #   @[Logit::Log(name: "user_logout", level: Logit::LogLevel::Debug)]
  #   def logout(user : User) : Nil
  #     # Custom span name and debug level
  #   end
  # end
  # ```
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
require "./backends/otlp"
require "./redaction"
require "./context"
require "./config"
require "./macros/register"
