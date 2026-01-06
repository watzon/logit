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

  describe "#bind" do
    it "adds a namespace binding" do
      backend = TestBackend.new("test", Logit::LogLevel::Info)
      backend.bind("MyLib::*", Logit::LogLevel::Debug)

      backend.bindings.size.should eq(1)
      backend.bindings[0].pattern.should eq("MyLib::*")
    end

    it "replaces existing binding for same pattern" do
      backend = TestBackend.new("test", Logit::LogLevel::Info)
      backend.bind("MyLib::*", Logit::LogLevel::Debug)
      backend.bind("MyLib::*", Logit::LogLevel::Warn)

      backend.bindings.size.should eq(1)
      backend.bindings[0].level.should eq(Logit::LogLevel::Warn)
    end
  end

  describe "#should_log? with namespace bindings" do
    it "uses default level when no bindings match" do
      backend = TestBackend.new("test", Logit::LogLevel::Warn)

      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 1,
        method_name: "test",
        class_name: "UnmatchedNamespace"
      )

      backend.should_log?(event).should be_false # Info < Warn
    end

    it "uses binding level when pattern matches" do
      backend = TestBackend.new("test", Logit::LogLevel::Warn)
      backend.bind("MyLib::**", Logit::LogLevel::Debug)

      event_debug = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test",
        level: Logit::LogLevel::Debug,
        code_file: "test.cr",
        code_line: 1,
        method_name: "test",
        class_name: "MyLib::HTTP::Client"
      )

      backend.should_log?(event_debug).should be_true
    end

    it "prefers most specific binding" do
      backend = TestBackend.new("test", Logit::LogLevel::Warn)
      backend.bind("MyLib::**", Logit::LogLevel::Debug)
      backend.bind("MyLib::HTTP::**", Logit::LogLevel::Error)

      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test",
        level: Logit::LogLevel::Warn,
        code_file: "test.cr",
        code_line: 1,
        method_name: "test",
        class_name: "MyLib::HTTP::Client"
      )

      # MyLib::HTTP::** is more specific than MyLib::**
      # Should use Error level, so Warn should not log
      backend.should_log?(event).should be_false
    end

    it "allows unmatched namespaces through default level" do
      backend = TestBackend.new("test", Logit::LogLevel::Info)
      backend.bind("MyLib::**", Logit::LogLevel::Warn)

      # MyLib should be filtered (Warn level)
      event_mylib = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 1,
        method_name: "test",
        class_name: "MyLib::HTTP::Client"
      )
      backend.should_log?(event_mylib).should be_false

      # OtherLib should pass (default Info level)
      event_other = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 1,
        method_name: "test",
        class_name: "OtherLib::Client"
      )
      backend.should_log?(event_other).should be_true
    end
  end
end

class TestBackend < Logit::Backend
  def initialize(@name = "test", @level = Logit::LogLevel::Info)
    @bindings = [] of Logit::NamespaceBinding
  end

  def log(event : Logit::Event) : Nil
    # Test implementation
  end
end
