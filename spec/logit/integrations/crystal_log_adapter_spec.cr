require "../../spec_helper"
require "../../../src/logit/integrations/crystal_log_adapter"
require "log"

# Test backend that captures events
class IntegrationCaptureBackend < Logit::Backend
  property captured : Array(Logit::Event) = [] of Logit::Event

  def initialize
    super("integration_capture", Logit::LogLevel::Trace)
  end

  def log(event : Logit::Event) : Nil
    return unless should_log?(event)
    @captured << event
  end

  def clear
    @captured.clear
  end
end

describe Logit::Integrations::CrystalLogAdapter do
  capture_backend = IntegrationCaptureBackend.new

  before_each do
    capture_backend.clear

    # Uninstall any previous adapter
    Logit::Integrations::CrystalLogAdapter.uninstall

    # Configure Logit with capture backend
    tracer = Logit::Tracer.new("test")
    tracer.add_backend(capture_backend)
    Logit::Tracer.default = tracer
  end

  after_each do
    # Clean up
    Logit::Integrations::CrystalLogAdapter.uninstall
  end

  describe ".install" do
    it "installs the adapter" do
      Logit::Integrations::CrystalLogAdapter.installed?.should be_false

      Logit::Integrations::CrystalLogAdapter.install

      Logit::Integrations::CrystalLogAdapter.installed?.should be_true
    end

    it "is idempotent" do
      Logit::Integrations::CrystalLogAdapter.install
      Logit::Integrations::CrystalLogAdapter.install
      Logit::Integrations::CrystalLogAdapter.install

      Logit::Integrations::CrystalLogAdapter.installed?.should be_true
    end
  end

  describe ".uninstall" do
    it "uninstalls the adapter" do
      Logit::Integrations::CrystalLogAdapter.install
      Logit::Integrations::CrystalLogAdapter.installed?.should be_true

      Logit::Integrations::CrystalLogAdapter.uninstall

      Logit::Integrations::CrystalLogAdapter.installed?.should be_false
    end
  end

  describe "Log capture" do
    it "captures Log.info calls" do
      Logit::Integrations::CrystalLogAdapter.install

      Log.info { "test message" }

      capture_backend.captured.size.should eq(1)
      event = capture_backend.captured[0]
      event.level.should eq(Logit::LogLevel::Info)
      event.attributes.get("log.message").should eq("test message")
    end

    it "captures Log.debug calls" do
      Logit::Integrations::CrystalLogAdapter.install

      Log.debug { "debug message" }

      capture_backend.captured.size.should eq(1)
      capture_backend.captured[0].level.should eq(Logit::LogLevel::Debug)
    end

    it "captures Log.warn calls" do
      Logit::Integrations::CrystalLogAdapter.install

      Log.warn { "warn message" }

      capture_backend.captured.size.should eq(1)
      capture_backend.captured[0].level.should eq(Logit::LogLevel::Warn)
    end

    it "captures Log.error calls" do
      Logit::Integrations::CrystalLogAdapter.install

      Log.error { "error message" }

      capture_backend.captured.size.should eq(1)
      capture_backend.captured[0].level.should eq(Logit::LogLevel::Error)
    end

    it "preserves Log source as class_name" do
      Logit::Integrations::CrystalLogAdapter.install

      log = Log.for("my.app.module")
      log.info { "from source" }

      capture_backend.captured.size.should eq(1)
      capture_backend.captured[0].class_name.should eq("my.app.module")
    end

    it "captures Log.context metadata" do
      Logit::Integrations::CrystalLogAdapter.install

      Log.context.set(request_id: "abc123")
      Log.info { "with context" }

      capture_backend.captured.size.should eq(1)
      event = capture_backend.captured[0]
      event.attributes.get("log.context.request_id").should eq("abc123")
    end

    it "captures entry data" do
      Logit::Integrations::CrystalLogAdapter.install

      Log.info &.emit("structured", user_id: 42)

      capture_backend.captured.size.should eq(1)
      event = capture_backend.captured[0]
      event.attributes.get("user_id").should eq("42")
    end

    it "captures exceptions" do
      Logit::Integrations::CrystalLogAdapter.install

      ex = Exception.new("test error")
      Log.error(exception: ex) { "with exception" }

      capture_backend.captured.size.should eq(1)
      event = capture_backend.captured[0]
      event.exception.should_not be_nil
      event.exception.try(&.message).should eq("test error")
      event.status.should eq(Logit::Status::Error)
    end

    it "inherits trace context from active Logit span" do
      Logit::Integrations::CrystalLogAdapter.install

      span = Logit::Span.new("parent_span")
      Logit::Span.push(span)

      begin
        Log.info { "inside logit span" }

        capture_backend.captured.size.should eq(1)
        event = capture_backend.captured[0]
        event.trace_id.should eq(span.trace_id)
        event.span_id.should eq(span.span_id)
      ensure
        Logit::Span.pop
      end
    end
  end

  describe "severity mapping" do
    it "maps Log::Severity::Trace to LogLevel::Trace" do
      Logit::Integrations::CrystalLogAdapter.install

      Log.trace { "trace" }

      capture_backend.captured[0].level.should eq(Logit::LogLevel::Trace)
    end

    it "maps Log::Severity::Notice to LogLevel::Info" do
      Logit::Integrations::CrystalLogAdapter.install

      Log.notice { "notice" }

      capture_backend.captured[0].level.should eq(Logit::LogLevel::Info)
    end

    it "maps Log::Severity::Fatal to LogLevel::Fatal" do
      Logit::Integrations::CrystalLogAdapter.install

      Log.fatal { "fatal" }

      capture_backend.captured[0].level.should eq(Logit::LogLevel::Fatal)
    end
  end
end
