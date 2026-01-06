require "../../version"

module Logit
  class Backend::OTLP < Backend
    # Configuration options for the OTLP backend.
    #
    # All timing values use `Time::Span` for type safety.
    # Resource attributes follow OpenTelemetry semantic conventions.
    struct Config
      # OTLP HTTP endpoint URL.
      #
      # Should point to an OTLP-compatible logs endpoint, typically
      # ending in `/v1/logs`.
      #
      # Examples:
      # - `http://localhost:4318/v1/logs` (local collector)
      # - `https://otlp.example.com/v1/logs` (remote collector)
      property endpoint : String

      # Maximum number of events per batch.
      #
      # When the buffer reaches this size, it will be flushed immediately.
      # Lower values reduce memory usage but increase HTTP overhead.
      property batch_size : Int32

      # Time between automatic flushes.
      #
      # The backend will flush buffered events at this interval even if
      # the batch size hasn't been reached. Set to a shorter interval
      # for lower latency at the cost of more HTTP requests.
      property flush_interval : Time::Span

      # HTTP headers to include with each request.
      #
      # Use this for authentication tokens or custom metadata.
      # Common headers:
      # - `Authorization: Bearer <token>`
      # - `X-API-Key: <key>`
      property headers : Hash(String, String)

      # HTTP request timeout.
      #
      # Applies to both connection and read timeouts. If the collector
      # doesn't respond within this time, the batch is dropped.
      property timeout : Time::Span

      # Resource attributes attached to all log records.
      #
      # These identify the source of logs in your observability platform.
      # Common attributes (following OpenTelemetry semantic conventions):
      # - `service.name` - Logical name of the service
      # - `service.version` - Version of the service
      # - `service.namespace` - Namespace for the service
      # - `deployment.environment` - Deployment environment (production, staging)
      # - `host.name` - Hostname of the machine
      property resource_attributes : Hash(String, String)

      # Instrumentation scope name.
      #
      # Identifies the library producing the logs. Defaults to "logit".
      property scope_name : String

      # Instrumentation scope version.
      #
      # Version of the instrumentation library. Defaults to Logit::VERSION.
      property scope_version : String

      def initialize(
        @endpoint : String,
        @batch_size : Int32 = 512,
        @flush_interval : Time::Span = 5.seconds,
        @headers : Hash(String, String) = {} of String => String,
        @timeout : Time::Span = 30.seconds,
        @resource_attributes : Hash(String, String) = {} of String => String,
        @scope_name : String = "logit",
        @scope_version : String = Logit::VERSION
      )
      end
    end
  end
end
