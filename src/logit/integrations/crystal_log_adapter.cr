require "log"
require "../tracing/span"
require "../tracing/tracer"
require "../events/event"
require "../log_level"
require "../utils/id_generator"

module Logit
  module Integrations
    # Adapter that captures Crystal Log calls and forwards them to Logit.
    #
    # This enables unified logging infrastructure where all logs flow through
    # Logit, providing OTLP export, trace context, and wide events.
    #
    # ## Installation
    #
    # ```crystal
    # require "logit"
    # require "logit/integrations/crystal_log_adapter"
    #
    # # Configure Logit first
    # Logit.configure do |config|
    #   config.console(Logit::LogLevel::Debug)
    #   config.otlp("http://localhost:4318/v1/logs")
    # end
    #
    # # Install the adapter
    # Logit::Integrations::CrystalLogAdapter.install
    #
    # # All Log.info/debug/etc calls now flow through Logit
    # Log.info { "This is captured by Logit" }
    # ```
    #
    # ## Trace Context Integration
    #
    # When installed, Crystal Log calls automatically inherit trace context
    # from any active Logit span:
    #
    # ```crystal
    # @[Logit::Log]
    # def process_request
    #   # This Log call inherits the trace context from the span
    #   Log.info { "Processing request" }
    #
    #   do_work
    #
    #   Log.info { "Request complete" }
    # end
    # ```
    #
    # ## Namespace Mapping
    #
    # Crystal Log sources are mapped to Logit namespaces, allowing you to
    # control logging per-source:
    #
    # ```crystal
    # Logit.configure do |config|
    #   console = config.console
    #
    #   # Control Crystal Log sources via namespace bindings
    #   config.bind "db.*", Logit::LogLevel::Debug, console
    #   config.bind "http.client", Logit::LogLevel::Warn, console
    # end
    # ```
    class CrystalLogAdapter < ::Log::Backend
      @@installed : Bool = false

      def initialize(dispatch_mode : ::Log::DispatchMode = :async)
        super(dispatch_mode)
      end

      def write(entry : ::Log::Entry) : Nil
        # Skip if Logit not properly configured
        return unless configured?

        # Map severity to Logit level
        level = map_severity(entry.severity)

        # Check if we should emit at this level for this source
        return unless Tracer.should_emit?(level, entry.source)

        # Get current span for trace context
        current_span = Span.current?

        # Create Logit event
        event = Event.new(
          trace_id: current_span.try(&.trace_id) || Utils::IDGenerator.trace_id,
          span_id: current_span.try(&.span_id) || Utils::IDGenerator.span_id,
          parent_span_id: current_span.try(&.parent_span_id),
          name: "log.#{entry.severity.to_s.downcase}",
          level: level,
          code_file: "",
          code_line: 0,
          method_name: "log",
          class_name: entry.source
        )

        # Add message as primary attribute
        event.attributes.set("log.message", entry.message)

        # Add Crystal Log source
        event.attributes.set("log.source", entry.source)

        # Add Log.context metadata
        entry.context.each do |key, value|
          event.attributes.set("log.context.#{key}", stringify_metadata_value(value))
        end

        # Add entry-specific data
        entry.data.each do |key, value|
          event.attributes.set(key.to_s, stringify_metadata_value(value))
        end

        # Add exception if present
        if ex = entry.exception
          event.exception = ExceptionInfo.from_exception(ex)
          event.status = Status::Error
        end

        # Add original Log severity for filtering/debugging
        event.attributes.set("log.severity", entry.severity.to_s)

        # Emit through Logit's tracer
        Tracer.default.emit(event)
      end

      # Install this adapter as Crystal Log backend.
      #
      # This replaces the default Log backend so all Log calls flow through Logit.
      # You should configure Logit backends BEFORE calling install.
      #
      # - *dispatch_mode*: How to dispatch log entries. Use `:sync` for synchronous
      #   (safer but may block) or `:async` for asynchronous (better performance).
      #   Default is `:sync` for reliability.
      #
      # ```crystal
      # # Configure Logit first
      # Logit.configure do |config|
      #   config.console(Logit::LogLevel::Debug)
      # end
      #
      # # Then install the adapter
      # Logit::Integrations::CrystalLogAdapter.install
      #
      # # Or with async dispatch for better performance
      # Logit::Integrations::CrystalLogAdapter.install(dispatch_mode: :async)
      # ```
      def self.install(dispatch_mode : ::Log::DispatchMode = :sync) : Nil
        return if @@installed

        # Create new adapter instance with specified dispatch mode
        adapter = new(dispatch_mode)

        # Use Log.setup to configure all sources to use our adapter
        # We bind at Trace level to capture everything - Logit handles filtering
        ::Log.setup do |c|
          c.bind "*", ::Log::Severity::Trace, adapter
        end

        @@installed = true
      end

      # Uninstall the adapter and restore default Log behavior.
      #
      # This resets Crystal Log to its default configuration (Info to STDOUT).
      def self.uninstall : Nil
        return unless @@installed

        # Reset to default Log configuration
        ::Log.setup(:info)

        @@installed = false
      end

      # Check if the adapter is currently installed.
      def self.installed? : Bool
        @@installed
      end

      private def configured? : Bool
        tracer = Tracer.default
        !tracer.backends.empty? && tracer.backends.any? { |b| !b.is_a?(Backend::Null) }
      end

      private def map_severity(severity : ::Log::Severity) : LogLevel
        case severity
        when ::Log::Severity::Trace  then LogLevel::Trace
        when ::Log::Severity::Debug  then LogLevel::Debug
        when ::Log::Severity::Info   then LogLevel::Info
        when ::Log::Severity::Notice then LogLevel::Info
        when ::Log::Severity::Warn   then LogLevel::Warn
        when ::Log::Severity::Error  then LogLevel::Error
        when ::Log::Severity::Fatal  then LogLevel::Fatal
        else                              LogLevel::Info
        end
      end

      # Convert Log::Metadata::Value to a string for Logit attributes
      private def stringify_metadata_value(value : ::Log::Metadata::Value) : String
        value.to_s
      end
    end
  end
end
