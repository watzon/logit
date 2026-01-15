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
    # ## Protection Against Library Interference
    #
    # Once installed, the adapter monkeypatches `Log.setup`, `Log.setup_from_env`,
    # and `Log::Builder#bind` to automatically reinstall itself after any library
    # attempts to reconfigure Crystal's logging. This ensures that all logs
    # continue to flow through Logit even when third-party libraries call
    # `Log.setup_from_env` at require time.
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
      @@adapter : CrystalLogAdapter? = nil
      @@dispatch_mode : ::Log::DispatchMode = :sync
      @@intercepting : Bool = false

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
      # Once installed, the adapter will automatically reinstall itself if any
      # library calls `Log.setup`, `Log.setup_from_env`, or modifies the Log
      # builder directly. This protects against third-party libraries that
      # configure logging at require time.
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
        @@dispatch_mode = dispatch_mode

        # Create new adapter instance with specified dispatch mode
        @@adapter = new(dispatch_mode)

        # Install without recursion guard (this is the real install)
        do_install

        @@installed = true
      end

      # Internal method to actually install the adapter into Log.
      # Called by install and by the intercepted Log methods.
      protected def self.do_install : Nil
        return unless (adapter = @@adapter)

        # Use Log.setup to configure all sources to use our adapter
        # We bind at Trace level to capture everything - Logit handles filtering
        #
        # Set intercepting flag to prevent infinite recursion when our own
        # Log.setup call triggers the interceptor
        @@intercepting = true
        begin
          ::Log.setup do |c|
            c.bind "*", ::Log::Severity::Trace, adapter
          end
        ensure
          @@intercepting = false
        end
      end

      # Reinstall the adapter after external code modified Log configuration.
      # This is called by the monkeypatched Log methods.
      def self.reinstall_if_needed : Nil
        return unless @@installed
        return if @@intercepting

        do_install
      end

      # Uninstall the adapter and restore default Log behavior.
      #
      # This resets Crystal Log to its default configuration (Info to STDOUT)
      # and removes the monkeypatches that protect against library interference.
      def self.uninstall : Nil
        return unless @@installed

        # Reset to default Log configuration
        @@intercepting = true
        begin
          ::Log.setup(:info)
        ensure
          @@intercepting = false
        end

        @@installed = false
        @@adapter = nil
      end

      # Check if the adapter is currently installed.
      def self.installed? : Bool
        @@installed
      end

      # Check if we're currently in the middle of an intercept operation.
      # Used by the monkeypatched methods to avoid infinite recursion.
      def self.intercepting? : Bool
        @@intercepting
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

# Monkeypatch Crystal's Log module to intercept configuration changes.
# This ensures Logit's adapter is reinstalled after any library tries to
# reconfigure logging (e.g., by calling Log.setup_from_env at require time).
class ::Log
  # Intercept Log.setup to reinstall our adapter after external configuration
  def self.setup(*, builder : ::Log::Builder = ::Log.builder, &) : Nil
    # Call the original implementation
    previous_def(builder: builder) { |c| yield c }

    # Reinstall Logit adapter if it was installed
    Logit::Integrations::CrystalLogAdapter.reinstall_if_needed
  end

  # Intercept Log.setup with sources parameter
  def self.setup(sources : String = "*", level : ::Log::Severity = ::Log::Severity::Info,
                 backend : ::Log::Backend = IOBackend.new, *,
                 builder : ::Log::Builder = ::Log.builder) : Nil
    # Call the original implementation
    previous_def(sources, level, backend, builder: builder)

    # Reinstall Logit adapter if it was installed
    Logit::Integrations::CrystalLogAdapter.reinstall_if_needed
  end

  # Intercept Log.setup with just level parameter
  def self.setup(level : ::Log::Severity = ::Log::Severity::Info,
                 backend : ::Log::Backend = IOBackend.new, *,
                 builder : ::Log::Builder = ::Log.builder) : Nil
    # Call the original implementation
    previous_def(level, backend, builder: builder)

    # Reinstall Logit adapter if it was installed
    Logit::Integrations::CrystalLogAdapter.reinstall_if_needed
  end

  # Intercept Log.setup_from_env to reinstall our adapter after environment-based configuration
  def self.setup_from_env(*, builder : ::Log::Builder = ::Log.builder,
                          default_level : ::Log::Severity = ::Log::Severity::Info,
                          default_sources = "*",
                          log_level_env = "LOG_LEVEL",
                          backend = ::Log::IOBackend.new) : Nil
    # Call the original implementation
    previous_def(
      builder: builder,
      default_level: default_level,
      default_sources: default_sources,
      log_level_env: log_level_env,
      backend: backend
    )

    # Reinstall Logit adapter if it was installed
    Logit::Integrations::CrystalLogAdapter.reinstall_if_needed
  end
end
