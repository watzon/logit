module Logit
  class Logger
    @@backends = [] of Backend
    @@mutex = Mutex.new

    def self.add_backend(backend : Backend) : Nil
      @@mutex.synchronize do
        @@backends << backend
      end
    end

    def self.remove_backend(name : String) : Nil
      @@mutex.synchronize do
        @@backends.reject! { |b| b.name == name }
      end
    end

    def self.clear_backends : Nil
      @@mutex.synchronize do
        @@backends.clear
      end
    end

    def self.backends : Array(Backend)
      @@mutex.synchronize do
        @@backends.dup
      end
    end

    def self.dispatch(entry : LogEntry, phase : Symbol) : Nil
      backends = @@mutex.synchronize do
        @@backends.dup
      end

      backends.each do |backend|
        if backend.should_log?(entry)
          begin
            backend.log(entry)
          rescue ex : Exception
            # Don't let logging errors break the application
            STDERR.puts "Logit: Backend #{backend.name} failed: #{ex.message}"
          end
        end
      end
    end

    def self.flush : Nil
      backends = @@mutex.synchronize do
        @@backends.dup
      end

      backends.each do |backend|
        begin
          backend.flush
        rescue ex : Exception
          STDERR.puts "Logit: Backend #{backend.name} flush failed: #{ex.message}"
        end
      end
    end

    def self.close : Nil
      backends_to_close = @@mutex.synchronize do
        backends = @@backends.dup
        @@backends.clear
        backends
      end

      backends_to_close.each do |backend|
        begin
          backend.close
        rescue ex : Exception
          STDERR.puts "Logit: Backend #{backend.name} close failed: #{ex.message}"
        end
      end
    end
  end
end
