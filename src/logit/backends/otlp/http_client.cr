require "http/client"
require "uri"
require "../../utils/safe_output"

module Logit
  class Backend::OTLP < Backend
    # HTTP client wrapper for sending OTLP payloads.
    #
    # Handles connection management, error handling, and request formatting.
    # All errors are caught and logged to STDERR - the client never raises.
    class HttpClient
      @endpoint : URI
      @headers : HTTP::Headers
      @timeout : Time::Span
      @client : HTTP::Client?
      @client_mutex : Mutex

      def initialize(endpoint : String, headers : Hash(String, String), @timeout : Time::Span)
        @endpoint = URI.parse(endpoint)
        @headers = HTTP::Headers.new
        @headers["Content-Type"] = "application/json"
        headers.each { |k, v| @headers[k] = v }
        @client_mutex = Mutex.new
      end

      # Sends a JSON payload to the OTLP endpoint.
      #
      # Returns true on success (2xx response), false otherwise.
      # Never raises - all errors are logged to STDERR.
      def send(payload : String) : Bool
        client = get_or_create_client
        return false unless client

        begin
          path = @endpoint.path
          path = "/v1/logs" if path.nil? || path.empty?

          response = client.post(path, headers: @headers, body: payload)
          handle_response(response)
        rescue ex : IO::Error | Socket::Error
          handle_error("Connection error", ex)
          false
        rescue ex : IO::TimeoutError
          handle_error("Timeout", ex)
          false
        rescue ex
          handle_error("Unexpected error", ex)
          false
        end
      end

      # Closes the HTTP client connection.
      def close : Nil
        @client_mutex.synchronize do
          @client.try(&.close)
          @client = nil
        end
      end

      private def get_or_create_client : HTTP::Client?
        @client_mutex.synchronize do
          return @client if @client

          begin
            client = HTTP::Client.new(@endpoint)
            client.connect_timeout = @timeout
            client.read_timeout = @timeout
            @client = client
            client
          rescue ex
            Utils::SafeOutput.safe_stderr_write(
              "Logit::OTLP: Failed to create HTTP client: #{ex.message}"
            )
            nil
          end
        end
      end

      private def handle_response(response : HTTP::Client::Response) : Bool
        case response.status_code
        when 200, 202
          true
        when 400
          Utils::SafeOutput.safe_stderr_write(
            "Logit::OTLP: Bad request (400) - check payload format"
          )
          false
        when 401, 403
          Utils::SafeOutput.safe_stderr_write(
            "Logit::OTLP: Authentication failed (#{response.status_code})"
          )
          false
        when 429
          Utils::SafeOutput.safe_stderr_write(
            "Logit::OTLP: Rate limited (429) - batch dropped"
          )
          false
        when 500..599
          Utils::SafeOutput.safe_stderr_write(
            "Logit::OTLP: Server error (#{response.status_code}) - batch dropped"
          )
          # Reset client on server errors (server might be restarting)
          reset_client
          false
        else
          Utils::SafeOutput.safe_stderr_write(
            "Logit::OTLP: Unexpected status (#{response.status_code})"
          )
          false
        end
      end

      private def handle_error(context : String, ex : Exception) : Nil
        Utils::SafeOutput.safe_stderr_write(
          "Logit::OTLP: #{context}: #{ex.message}"
        )
        # Reset client on connection errors
        reset_client
      end

      private def reset_client : Nil
        @client_mutex.synchronize do
          @client.try(&.close)
          @client = nil
        end
      end
    end
  end
end
