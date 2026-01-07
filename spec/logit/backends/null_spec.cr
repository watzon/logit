require "../../spec_helper"

describe Logit::Backend::Null do
  describe "#initialize" do
    it "creates a null backend with Fatal level" do
      backend = Logit::Backend::Null.new
      backend.name.should eq("null")
      backend.level.should eq(Logit::LogLevel::Fatal)
    end
  end

  describe "#log" do
    it "discards all events without error" do
      backend = Logit::Backend::Null.new
      event = Logit::Event.new(
        trace_id: "abc123",
        span_id: "def456",
        name: "test",
        level: Logit::LogLevel::Info,
        code_file: __FILE__,
        code_line: __LINE__,
        method_name: "test",
        class_name: "Test"
      )

      # Should not raise
      backend.log(event)
    end
  end

  describe "#should_log?" do
    it "always returns false" do
      backend = Logit::Backend::Null.new
      event = Logit::Event.new(
        trace_id: "abc123",
        span_id: "def456",
        name: "test",
        level: Logit::LogLevel::Fatal,
        code_file: __FILE__,
        code_line: __LINE__,
        method_name: "test",
        class_name: "Test"
      )

      backend.should_log?(event).should be_false
    end
  end

  describe "#should_log_level?" do
    it "always returns false for any level and namespace" do
      backend = Logit::Backend::Null.new

      backend.should_log_level?(Logit::LogLevel::Trace, "any").should be_false
      backend.should_log_level?(Logit::LogLevel::Debug, "any").should be_false
      backend.should_log_level?(Logit::LogLevel::Info, "any").should be_false
      backend.should_log_level?(Logit::LogLevel::Warn, "any").should be_false
      backend.should_log_level?(Logit::LogLevel::Error, "any").should be_false
      backend.should_log_level?(Logit::LogLevel::Fatal, "any").should be_false
    end
  end

  describe "#flush" do
    it "is a no-op" do
      backend = Logit::Backend::Null.new
      backend.flush # Should not raise
    end
  end

  describe "#close" do
    it "is a no-op" do
      backend = Logit::Backend::Null.new
      backend.close # Should not raise
    end
  end
end

describe "Default Tracer with NullBackend" do
  it "uses NullBackend by default when not configured" do
    # Reset tracer to default
    Logit::Tracer.default = Logit::Tracer.new("test_default")

    # Get fresh default tracer
    tracer = Logit::Tracer.default
    tracer.backends.size.should eq(0)
  end
end
