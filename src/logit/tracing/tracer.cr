require "../backend"
require "../events/event"

module Logit
  class Tracer
    property name : String
    property backends : Array(Backend)

    def initialize(@name)
      @backends = [] of Backend
    end

    # Add backend
    def add_backend(backend : Backend) : Nil
      @backends << backend
    end

    # Remove backend by name
    def remove_backend(name : String) : Nil
      @backends.reject! { |b| b.name == name }
    end

    # Log event to all backends
    def emit(event : Event) : Nil
      @backends.each do |backend|
        begin
          backend.log(event)
        rescue ex
          # Error isolation - don't let one backend failure affect others
          STDERR << "Logit: Backend '#{backend.name}' failed: " << ex.message << "\n"
        end
      end
    end

    # Flush all backends
    def flush : Nil
      @backends.each(&.flush)
    end

    # Close all backends
    def close : Nil
      @backends.each(&.close)
    end

    # Default tracer (convenience)
    @@default : Tracer?

    def self.default : Tracer
      @@default ||= new("default").tap { |t| t.add_backend(Backend::Console.new) }
    end

    def self.default=(tracer : Tracer)
      @@default = tracer
    end
  end
end
