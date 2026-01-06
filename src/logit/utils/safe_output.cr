module Logit
  module Utils
    module SafeOutput
      # Silently attempt to write to STDERR; never raises
      # This is critical for a logging library - it must NEVER crash the app
      def self.safe_stderr_write(message : String) : Nil
        begin
          STDERR << message << "\n"
          STDERR.flush
        rescue
          # Completely silent - if we can't write errors, we can't write errors
          # This is the safest fallback for a logging library
        end
      end

      # Attempt to write to an alternative output if STDERR fails
      def self.safe_error_write(message : String, fallback : IO? = nil) : Nil
        begin
          STDERR << message << "\n"
          STDERR.flush
        rescue
          begin
            if fb = fallback
              fb << message << "\n"
              fb.flush
            end
          rescue
            # Both outputs failed - give up silently
          end
        end
      end
    end
  end
end
