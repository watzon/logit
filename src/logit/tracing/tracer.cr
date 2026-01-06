require "../backend"
require "../events/event"
require "../utils/safe_output"

module Logit
  # Routes log events to registered backends.
  #
  # The Tracer is responsible for:
  # - Managing a collection of backends
  # - Emitting events to all applicable backends
  # - Providing error isolation (one backend failure doesn't affect others)
  # - Thread-safe backend management
  #
  # Most applications use the default tracer, which is set up automatically
  # by `Logit.configure`. You typically don't need to interact with the
  # Tracer directly.
  #
  # ## Default Tracer
  #
  # The default tracer is used by all instrumented methods:
  #
  # ```crystal
  # # Get the default tracer
  # tracer = Logit::Tracer.default
  #
  # # Check if logging is enabled at a level
  # if Logit::Tracer.should_emit?(Logit::LogLevel::Debug)
  #   # ... expensive debug operation
  # end
  # ```
  #
  # ## Custom Tracers
  #
  # For advanced use cases, you can create named tracers:
  #
  # ```crystal
  # Logit.configure do |config|
  #   tracer = Logit::Tracer.new("audit")
  #   tracer.add_backend(Logit::Backend::File.new("audit.log"))
  #   config.add_tracer("audit", tracer)
  # end
  # ```
  class Tracer
    # The name of this tracer.
    property name : String

    # The backends registered with this tracer.
    property backends : Array(Backend)

    @mutex : Mutex

    # Creates a new tracer with the given name.
    def initialize(@name)
      @backends = [] of Backend
      @mutex = Mutex.new
    end

    # Adds a backend to this tracer.
    #
    # Thread-safe. The backend will receive all events emitted to this tracer
    # that pass its level and namespace filters.
    def add_backend(backend : Backend) : Nil
      @mutex.synchronize do
        @backends << backend
      end
    end

    # Removes a backend by name.
    #
    # Thread-safe. The backend will no longer receive events.
    def remove_backend(name : String) : Nil
      @mutex.synchronize do
        @backends.reject! { |b| b.name == name }
      end
    end

    # Emits an event to all registered backends.
    #
    # Each backend decides whether to log the event based on its level and
    # namespace bindings. Backend failures are isolated - if one backend
    # fails, others still receive the event.
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

    # Flushes all backends.
    #
    # Call this to ensure buffered log data is written. Useful before
    # application shutdown or when you need logs to be immediately visible.
    def flush : Nil
      backends_snapshot = @mutex.synchronize { @backends.dup }
      backends_snapshot.each(&.flush)
    end

    # Closes all backends and releases resources.
    #
    # Call this during application shutdown to ensure log files are properly
    # closed and all data is flushed.
    def close : Nil
      backends_snapshot = @mutex.synchronize { @backends.dup }
      backends_snapshot.each(&.close)
    end

    @@default : Tracer?
    @@default_mutex = Mutex.new

    # Returns the default tracer.
    #
    # If no tracer has been configured via `Logit.configure`, creates a
    # default tracer with a console backend at Info level.
    def self.default : Tracer
      @@default_mutex.synchronize do
        @@default ||= new("default").tap { |t| t.add_backend(Backend::Console.new) }
      end
    end

    # Sets the default tracer.
    #
    # Called automatically by `Logit.configure`. You typically don't need
    # to call this directly.
    def self.default=(tracer : Tracer)
      @@default_mutex.synchronize do
        @@default = tracer
      end
    end

    # Checks if any backend will emit at this level.
    #
    # Use this for early filtering to avoid expensive operations when
    # logging is disabled at a particular level.
    #
    # ```crystal
    # if Logit::Tracer.should_emit?(Logit::LogLevel::Debug)
    #   # Only compute expensive debug info if it will be logged
    #   debug_info = compute_expensive_debug_info
    # end
    # ```
    def self.should_emit?(level : LogLevel) : Bool
      tracer = @@default_mutex.synchronize { @@default }
      return false unless tracer

      backends = tracer.@mutex.synchronize { tracer.@backends.dup }
      backends.any? { |b| level >= b.level }
    end

    # Checks if any backend will emit at this level for a specific namespace.
    #
    # Takes namespace bindings into account for more precise early filtering.
    def self.should_emit?(level : LogLevel, namespace : String) : Bool
      tracer = @@default_mutex.synchronize { @@default }
      return false unless tracer

      backends = tracer.@mutex.synchronize { tracer.@backends.dup }
      backends.any? { |b| b.should_log_level?(level, namespace) }
    end
  end
end
