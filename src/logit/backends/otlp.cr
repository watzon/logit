require "../backend"
require "./otlp/config"
require "./otlp/payload_builder"
require "./otlp/http_client"
require "./otlp/batch_processor"

module Logit
  # Backend that exports logs to an OpenTelemetry collector via OTLP/HTTP.
  #
  # Events are batched and sent as OTLP JSON payloads. The backend flushes
  # either when the batch size is reached or the flush interval elapses.
  #
  # ## Basic Usage
  #
  # ```crystal
  # Logit.configure do |config|
  #   config.otlp("http://localhost:4318/v1/logs")
  # end
  # ```
  #
  # ## With Authentication
  #
  # ```crystal
  # Logit.configure do |config|
  #   config.otlp(
  #     "https://otlp.example.com/v1/logs",
  #     headers: {"Authorization" => "Bearer #{ENV["OTLP_TOKEN"]}"},
  #     resource_attributes: {
  #       "service.name" => "my-app",
  #       "service.version" => "1.0.0",
  #       "deployment.environment" => "production"
  #     }
  #   )
  # end
  # ```
  #
  # ## Configuration Options
  #
  # - **endpoint**: OTLP HTTP endpoint URL (required)
  # - **batch_size**: Max events per batch (default: 512)
  # - **flush_interval**: Time between flushes (default: 5 seconds)
  # - **headers**: HTTP headers for auth (default: empty)
  # - **timeout**: HTTP timeout (default: 30 seconds)
  # - **resource_attributes**: Service metadata (default: empty)
  #
  # ## Error Handling
  #
  # The backend never crashes the application. Network errors and failed
  # batches are logged to STDERR and dropped.
  class Backend::OTLP < Backend
    @config : Config
    @batch_processor : BatchProcessor
    @http_client : HttpClient
    @payload_builder : PayloadBuilder

    # Creates a new OTLP backend with the given configuration.
    def initialize(@config : Config, name = "otlp", level = LogLevel::Info)
      super(name, level)

      @payload_builder = PayloadBuilder.new(
        resource_attributes: @config.resource_attributes,
        scope_name: @config.scope_name,
        scope_version: @config.scope_version
      )

      @http_client = HttpClient.new(
        @config.endpoint,
        @config.headers,
        @config.timeout
      )

      @batch_processor = BatchProcessor.new(
        @config.batch_size,
        @config.flush_interval
      ) do |events|
        send_batch(events)
      end

      @batch_processor.start
    end

    # Logs an event by adding it to the batch buffer.
    #
    # The event will be sent when the batch size is reached or
    # the flush interval elapses.
    def log(event : Event) : Nil
      return unless should_log?(event)
      @batch_processor.add(event)
    end

    # Forces an immediate flush of buffered events.
    def flush : Nil
      @batch_processor.flush
    end

    # Stops the batch processor and closes the HTTP client.
    #
    # Flushes any remaining buffered events before closing.
    def close : Nil
      @batch_processor.stop
      @http_client.close
    end

    private def send_batch(events : Array(Event)) : Nil
      return if events.empty?

      payload = @payload_builder.build(events)
      @http_client.send(payload)
    rescue ex
      Utils::SafeOutput.safe_stderr_write(
        "Logit::OTLP: Failed to send batch: #{ex.message}"
      )
    end
  end
end
