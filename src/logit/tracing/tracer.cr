require "../backend"
require "../events/event"
require "../utils/safe_output"

module Logit
  class Tracer
    property name : String
    property backends : Array(Backend)

    @mutex : Mutex

    def initialize(@name)
      @backends = [] of Backend
      @mutex = Mutex.new
    end

    # Add backend
    def add_backend(backend : Backend) : Nil
      @mutex.synchronize do
        @backends << backend
      end
    end

    # Remove backend by name
    def remove_backend(name : String) : Nil
      @mutex.synchronize do
        @backends.reject! { |b| b.name == name }
      end
    end

    # Log event to all backends
    def emit(event : Event) : Nil
      backends_snapshot = @mutex.synchronize { @backends.dup }
      backends_snapshot.each do |backend|
        begin
          backend.log(event)
        rescue ex
          # Error isolation - don't let one backend failure affect others
          Logit::Utils::SafeOutput.safe_stderr_write("Logit: Backend '#{backend.name}' failed: #{ex.message}")
        end
      end
    end

    # Flush all backends
    def flush : Nil
      backends_snapshot = @mutex.synchronize { @backends.dup }
      backends_snapshot.each(&.flush)
    end

    # Close all backends
    def close : Nil
      backends_snapshot = @mutex.synchronize { @backends.dup }
      backends_snapshot.each(&.close)
    end

    # Default tracer (convenience)
    @@default : Tracer?
    @@default_mutex = Mutex.new

    def self.default : Tracer
      @@default_mutex.synchronize do
        @@default ||= new("default").tap { |t| t.add_backend(Backend::Console.new) }
      end
    end

    def self.default=(tracer : Tracer)
      @@default_mutex.synchronize do
        @@default = tracer
      end
    end

    # Check if any backend will emit at this level (for early filtering)
    def self.should_emit?(level : LogLevel) : Bool
      tracer = @@default_mutex.synchronize { @@default }
      return false unless tracer

      backends = tracer.@mutex.synchronize { tracer.@backends.dup }
      backends.any? { |b| level >= b.level }
    end

    # Check if any backend will emit at this level for a namespace (for early filtering)
    def self.should_emit?(level : LogLevel, namespace : String) : Bool
      tracer = @@default_mutex.synchronize { @@default }
      return false unless tracer

      backends = tracer.@mutex.synchronize { tracer.@backends.dup }
      backends.any? { |b| b.should_log_level?(level, namespace) }
    end
  end
end
