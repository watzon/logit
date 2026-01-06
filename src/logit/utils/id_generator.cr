module Logit
  module Utils
    module IDGenerator
      # Generate W3C trace ID (16 bytes, 32 hex chars)
      def self.trace_id : String
        Random::Secure.hex(16)
      end

      # Generate W3C span ID (8 bytes, 16 hex chars)
      def self.span_id : String
        Random::Secure.hex(8)
      end
    end
  end
end
