require "../../spec_helper"
require "../../../src/logit"

describe Logit::Formatter::Human do
  describe "#format" do
    it "formats an event as human-readable text" do
      formatter = Logit::Formatter::Human.new

      event = Logit::Event.new(
        trace_id: "trace1234567890abcdef1234567890ab",
        span_id: "span4567",
        name: "test.operation",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 42,
        method_name: "test_method",
        class_name: "TestClass"
      )

      output = formatter.format(event)
      output.should contain("INFO")
      output.should contain("test.cr:42")
      output.should contain("TestClass#test_method")
      # No trace ID for root spans (no parent_span_id)
    end

    it "includes duration when present" do
      formatter = Logit::Formatter::Human.new

      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test.operation",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 42,
        method_name: "test_method",
        class_name: "TestClass"
      )
      event.duration_ms = 150

      output = formatter.format(event)
      output.should contain("150ms")
    end

    it "includes exception when present" do
      formatter = Logit::Formatter::Human.new

      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test.operation",
        level: Logit::LogLevel::Error,
        code_file: "test.cr",
        code_line: 42,
        method_name: "test_method",
        class_name: "TestClass"
      )
      event.exception = Logit::ExceptionInfo.new("TestError", "Something went wrong")

      output = formatter.format(event)
      output.should contain("✖")
      output.should contain("TestError")
      output.should contain("Something went wrong")
    end

    it "includes attributes when present" do
      formatter = Logit::Formatter::Human.new

      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test.operation",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 42,
        method_name: "test_method",
        class_name: "TestClass"
      )
      event.attributes.set("user_id", "12345")

      output = formatter.format(event)
      # Attributes are not shown in the default output anymore
      # Only code.arguments and code.return have special handling
    end

    it "colorizes log levels" do
      formatter = Logit::Formatter::Human.new

      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test.operation",
        level: Logit::LogLevel::Error,
        code_file: "test.cr",
        code_line: 42,
        method_name: "test_method",
        class_name: "TestClass"
      )

      output = formatter.format(event)
      output.should contain("\e[") # ANSI color codes
    end

    it "shows trace ID for nested spans" do
      formatter = Logit::Formatter::Human.new

      event = Logit::Event.new(
        trace_id: "trace1234567890abcdef1234567890ab",
        span_id: "span4567",
        parent_span_id: "parent123",
        name: "test.operation",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 42,
        method_name: "test_method",
        class_name: "TestClass"
      )

      output = formatter.format(event)
      output.should contain("[trace123") # First 8 chars of trace_id
    end
  end
end
