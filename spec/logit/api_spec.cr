require "../spec_helper"

# Test backend that captures events
class CaptureBackend < Logit::Backend
  property captured : Array(Logit::Event) = [] of Logit::Event

  def initialize
    super("capture", Logit::LogLevel::Trace)
  end

  def log(event : Logit::Event) : Nil
    return unless should_log?(event)
    @captured << event
  end

  def clear
    @captured.clear
  end
end

describe Logit::API do
  # Set up a capture backend before tests
  capture_backend = CaptureBackend.new

  before_each do
    capture_backend.clear

    # Configure Logit with capture backend
    tracer = Logit::Tracer.new("test")
    tracer.add_backend(capture_backend)
    Logit::Tracer.default = tracer
  end

  describe "string-based logging" do
    it "logs at trace level" do
      Logit.trace("trace message")
      capture_backend.captured.size.should eq(1)
      capture_backend.captured[0].level.should eq(Logit::LogLevel::Trace)
      capture_backend.captured[0].attributes.get("log.message").should eq("trace message")
    end

    it "logs at debug level" do
      Logit.debug("debug message")
      capture_backend.captured.size.should eq(1)
      capture_backend.captured[0].level.should eq(Logit::LogLevel::Debug)
    end

    it "logs at info level" do
      Logit.info("info message")
      capture_backend.captured.size.should eq(1)
      capture_backend.captured[0].level.should eq(Logit::LogLevel::Info)
    end

    it "logs at warn level" do
      Logit.warn("warn message")
      capture_backend.captured.size.should eq(1)
      capture_backend.captured[0].level.should eq(Logit::LogLevel::Warn)
    end

    it "logs at error level" do
      Logit.error("error message")
      capture_backend.captured.size.should eq(1)
      capture_backend.captured[0].level.should eq(Logit::LogLevel::Error)
    end

    it "logs at fatal level" do
      Logit.fatal("fatal message")
      capture_backend.captured.size.should eq(1)
      capture_backend.captured[0].level.should eq(Logit::LogLevel::Fatal)
    end
  end

  describe "lazy evaluation logging" do
    it "evaluates block when logging is enabled" do
      evaluated = false
      Logit.debug { evaluated = true; "lazy message" }

      evaluated.should be_true
      capture_backend.captured.size.should eq(1)
      capture_backend.captured[0].attributes.get("log.message").should eq("lazy message")
    end

    it "does not evaluate block when logging is disabled" do
      # Set backend to only log Error and above
      capture_backend.level = Logit::LogLevel::Error

      evaluated = false
      Logit.debug { evaluated = true; "should not evaluate" }

      evaluated.should be_false
      capture_backend.captured.size.should eq(0)

      # Reset for other tests
      capture_backend.level = Logit::LogLevel::Trace
    end
  end

  describe "structured attributes" do
    it "adds keyword arguments as attributes" do
      Logit.info("structured log", user_id: 123, action: "login")

      capture_backend.captured.size.should eq(1)
      event = capture_backend.captured[0]
      event.attributes.get("user_id").should eq(123_i64)
      event.attributes.get("action").should eq("login")
    end
  end

  describe "exception logging" do
    it "logs exception with full details" do
      ex = Exception.new("test error")
      Logit.exception("operation failed", ex)

      capture_backend.captured.size.should eq(1)
      event = capture_backend.captured[0]
      event.level.should eq(Logit::LogLevel::Error)
      event.status.should eq(Logit::Status::Error)
      event.exception.should_not be_nil
      event.exception.try(&.message).should eq("test error")
    end

    it "logs exception at custom level" do
      ex = Exception.new("warning error")
      Logit.exception("minor issue", ex, Logit::LogLevel::Warn)

      capture_backend.captured.size.should eq(1)
      capture_backend.captured[0].level.should eq(Logit::LogLevel::Warn)
    end
  end

  describe "trace context integration" do
    it "inherits trace context from active span" do
      # Create and push a span
      span = Logit::Span.new("parent_operation")
      Logit::Span.push(span)

      begin
        Logit.info("inside span")

        capture_backend.captured.size.should eq(1)
        event = capture_backend.captured[0]
        event.trace_id.should eq(span.trace_id)
        event.span_id.should eq(span.span_id)
      ensure
        Logit::Span.pop
      end
    end

    it "generates new trace context when no span is active" do
      Logit.info("no span")

      capture_backend.captured.size.should eq(1)
      event = capture_backend.captured[0]
      event.trace_id.should_not be_empty
      event.span_id.should_not be_empty
    end
  end
end
