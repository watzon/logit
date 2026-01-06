require "./tracing/tracer"
require "./backend"
require "./namespace_binding"
require "./backends/console"
require "./backends/file"
require "./formatter"
require "./formatters/human"

module Logit
  class Config
    property tracers : Hash(String, Tracer)
    property default_tracer_name : String

    def initialize
      @tracers = {} of String => Tracer
      @default_tracer_name = "default"
    end

    def self.configure(&) : Config
      config = new
      yield config
      config
    end

    def console(level = LogLevel::Info, formatter = Formatter::Human.new) : Backend::Console
      backend = Backend::Console.new("console", level, formatter)
      add_backend(backend)
      backend
    end

    def file(path : String, level = LogLevel::Info) : Backend::File
      backend = Backend::File.new(path, "file", level)
      add_backend(backend)
      backend
    end

    def add_tracer(name : String, tracer : Tracer) : Nil
      @tracers[name] = tracer
    end

    def add_backend(backend : Backend) : Nil
      tracer = @tracers[@default_tracer_name]?
      unless tracer
        tracer = Tracer.new(@default_tracer_name)
        @tracers[@default_tracer_name] = tracer
      end
      tracer.add_backend(backend)
    end

    # Bind a namespace pattern to a log level for a specific backend
    def bind(pattern : String, level : LogLevel, backend : Backend) : Nil
      backend.bind(pattern, level)
    end

    def build : Nil
      # Set default tracer
      if default = @tracers[@default_tracer_name]?
        Tracer.default = default
      end
    end
  end

  def self.configure(&) : Config
    config = Config.configure do |config|
      yield config
    end
    config.build
    config
  end
end
