require "../spec_helper"
require "../../src/logit"

describe Logit::Backend do
  describe "#initialize" do
    it "creates a backend with name and level" do
      backend = TestBackend.new("test", Logit::LogLevel::Warn)
      backend.name.should eq("test")
      backend.level.should eq(Logit::LogLevel::Warn)
    end
  end

  describe "#should_log?" do
    it "returns true when event level >= backend level" do
      backend = TestBackend.new("test", Logit::LogLevel::Warn)

      event_error = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test",
        level: Logit::LogLevel::Error,
        code_file: "test.cr",
        code_line: 1,
        method_name: "test",
        class_name: "Test"
      )

      event_warn = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test",
        level: Logit::LogLevel::Warn,
        code_file: "test.cr",
        code_line: 1,
        method_name: "test",
        class_name: "Test"
      )

      backend.should_log?(event_error).should be_true
      backend.should_log?(event_warn).should be_true
    end

    it "returns false when event level < backend level" do
      backend = TestBackend.new("test", Logit::LogLevel::Warn)

      event_info = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 1,
        method_name: "test",
        class_name: "Test"
      )

      backend.should_log?(event_info).should be_false
    end
  end

  describe "#flush" do
    it "is a no-op by default" do
      backend = TestBackend.new("test")
      backend.flush # Should not raise
    end
  end

  describe "#close" do
    it "is a no-op by default" do
      backend = TestBackend.new("test")
      backend.close # Should not raise
    end
  end
end

class TestBackend < Logit::Backend
  def initialize(@name = "test", @level = Logit::LogLevel::Info)
  end

  def log(event : Logit::Event) : Nil
    # Test implementation
  end
end
