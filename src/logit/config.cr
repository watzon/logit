require "./tracing/tracer"
require "./backend"
require "./namespace_binding"
require "./backends/console"
require "./backends/file"
require "./formatter"
require "./formatters/human"
require "./redaction"

module Logit
  # Configuration builder for setting up Logit logging infrastructure.
  #
  # Use `Logit.configure` to create and apply a configuration. The config
  # provides a fluent API for adding backends, setting up namespace filtering,
  # and configuring redaction patterns.
  #
  # ## Basic Configuration
  #
  # ```crystal
  # Logit.configure do |config|
  #   config.console(level: Logit::LogLevel::Debug)
  # end
  # ```
  #
  # ## Multiple Backends
  #
  # ```crystal
  # Logit.configure do |config|
  #   # Console for development
  #   console = config.console(level: Logit::LogLevel::Info)
  #
  #   # JSON file for production logs
  #   file = config.file("logs/app.log", level: Logit::LogLevel::Debug)
  #
  #   # Different levels per namespace
  #   config.bind("MyApp::Database::*", Logit::LogLevel::Warn, console)
  #   config.bind("MyApp::Http::*", Logit::LogLevel::Debug, file)
  # end
  # ```
  #
  # ## Redaction
  #
  # ```crystal
  # Logit.configure do |config|
  #   config.console
  #
  #   # Enable common security patterns (password, token, api_key, etc.)
  #   config.redact_common_patterns
  #
  #   # Add custom patterns
  #   config.redact_patterns(/ssn/i, /credit_card/i)
  # end
  # ```
  class Config
    # Registered tracers by name.
    property tracers : Hash(String, Tracer)

    # Name of the default tracer used by instrumented methods.
    property default_tracer_name : String

    def initialize
      @tracers = {} of String => Tracer
      @default_tracer_name = "default"
    end

    # Creates a new Config, yields it for configuration, and returns it.
    # Typically you should use `Logit.configure` instead, which also applies
    # the configuration.
    def self.configure(&) : Config
      config = new
      yield config
      config
    end

    # Adds a console backend that writes to STDOUT.
    #
    # The console backend uses `Formatter::Human` by default, which produces
    # colorized, human-readable output suitable for development.
    #
    # - *level*: Minimum log level (default: Info)
    # - *formatter*: Output formatter (default: Human)
    # - *buffered*: Whether to buffer output (default: false for immediate display)
    #
    # Returns the created backend for further configuration (e.g., namespace bindings).
    #
    # ```crystal
    # config.console(level: Logit::LogLevel::Debug)
    # ```
    def console(level = LogLevel::Info, formatter = Formatter::Human.new, buffered : Bool = false) : Backend::Console
      backend = Backend::Console.new("console", level, formatter)
      backend.buffered = buffered
      add_backend(backend)
      backend
    end

    # Adds a file backend that writes to the specified path.
    #
    # The file backend uses `Formatter::JSON` by default, which produces
    # structured JSON output suitable for log aggregation systems.
    #
    # - *path*: Path to the log file (will be created if it doesn't exist)
    # - *level*: Minimum log level (default: Info)
    # - *buffered*: Whether to buffer output (default: true for performance)
    #
    # Returns the created backend for further configuration (e.g., namespace bindings).
    #
    # ```crystal
    # config.file("logs/app.log", level: Logit::LogLevel::Debug)
    # ```
    #
    # NOTE: The file is opened with mode 0o600 (owner read/write only) by default.
    # Symlinks are not followed unless explicitly enabled in `Backend::File`.
    def file(path : String, level = LogLevel::Info, buffered : Bool = true) : Backend::File
      backend = Backend::File.new(path, "file", level)
      backend.buffered = buffered
      add_backend(backend)
      backend
    end

    # Registers a named tracer.
    #
    # Most applications only need the default tracer, but you can create
    # additional named tracers for advanced use cases like multi-tenant logging.
    def add_tracer(name : String, tracer : Tracer) : Nil
      @tracers[name] = tracer
    end

    # Adds a backend to the default tracer.
    #
    # Creates the default tracer if it doesn't exist. For most applications,
    # use `console` or `file` methods instead, which call this internally.
    def add_backend(backend : Backend) : Nil
      tracer = @tracers[@default_tracer_name]?
      unless tracer
        tracer = Tracer.new(@default_tracer_name)
        @tracers[@default_tracer_name] = tracer
      end
      tracer.add_backend(backend)
    end

    # Binds a namespace pattern to a log level for a specific backend.
    #
    # This allows fine-grained control over which namespaces (classes) log at
    # which levels. More specific patterns take precedence over less specific ones.
    #
    # Pattern syntax:
    # - `MyApp::*` - matches any class directly in MyApp
    # - `MyApp::**` - matches any class in MyApp or any nested namespace
    # - `MyApp::Http::*` - matches classes in MyApp::Http
    #
    # ```crystal
    # console = config.console
    #
    # # Only log warnings and above from database classes
    # config.bind("MyApp::Database::*", Logit::LogLevel::Warn, console)
    #
    # # But log everything from the query builder
    # config.bind("MyApp::Database::QueryBuilder", Logit::LogLevel::Debug, console)
    # ```
    def bind(pattern : String, level : LogLevel, backend : Backend) : Nil
      backend.bind(pattern, level)
    end

    # Adds global redaction patterns that apply to all instrumented methods.
    #
    # Any argument name matching one of these regex patterns will have its
    # value replaced with `[REDACTED]` in the logs.
    #
    # ```crystal
    # config.redact_patterns(/ssn/i, /credit_card/i, /social_security/i)
    # ```
    def redact_patterns(*patterns : Regex) : Nil
      patterns.each { |p| Redaction.add_pattern(p) }
    end

    # Enables a set of common security-related redaction patterns.
    #
    # This is a convenience method that adds patterns for commonly sensitive
    # argument names including: password, secret, token, api_key, auth,
    # credential, private_key, access_key, and bearer.
    #
    # ```crystal
    # config.redact_common_patterns
    # ```
    def redact_common_patterns : Nil
      Redaction.enable_common_patterns
    end

    # Finalizes the configuration by setting the default tracer.
    # Called automatically by `Logit.configure`.
    def build : Nil
      # Set default tracer
      if default = @tracers[@default_tracer_name]?
        Tracer.default = default
      end
    end
  end

  # Configures Logit with the provided block and applies the configuration.
  #
  # This is the main entry point for setting up Logit. The configuration is
  # applied immediately after the block completes.
  #
  # ```crystal
  # Logit.configure do |config|
  #   config.console(level: Logit::LogLevel::Debug)
  #   config.file("logs/app.log")
  #   config.redact_common_patterns
  # end
  # ```
  #
  # If you don't call `configure`, Logit uses a default console backend at
  # Info level.
  def self.configure(&) : Config
    config = Config.configure do |config|
      yield config
    end
    config.build
    config
  end
end
