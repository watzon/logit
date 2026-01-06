require "../../spec_helper"
require "../../../src/logit"

describe Logit::Formatter::JSON do
  describe "#format" do
    it "formats an event as JSON" do
      formatter = Logit::Formatter::JSON.new

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

      output = formatter.format(event)
      parsed = JSON.parse(output)

      parsed["trace_id"].as_s.should eq("trace123")
      parsed["span_id"].as_s.should eq("span456")
      parsed["name"].as_s.should eq("test.operation")
      parsed["level"].as_s.should eq("info")
      parsed["code"]["file"].as_s.should eq("test.cr")
      parsed["code"]["line"].as_i.should eq(42)
      parsed["code"]["function"].as_s.should eq("test_method")
      parsed["code"]["namespace"].as_s.should eq("TestClass")
    end

    it "includes parent_span_id when present" do
      formatter = Logit::Formatter::JSON.new

      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test.operation",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 42,
        method_name: "test_method",
        class_name: "TestClass",
        parent_span_id: "parent789"
      )

      output = formatter.format(event)
      parsed = JSON.parse(output)

      parsed["parent_span_id"].as_s.should eq("parent789")
    end

    it "includes duration_ms" do
      formatter = Logit::Formatter::JSON.new

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
      parsed = JSON.parse(output)

      parsed["duration_ms"].as_i.should eq(150)
    end

    it "includes attributes when present" do
      formatter = Logit::Formatter::JSON.new

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
      event.attributes.set("custom", "value")

      output = formatter.format(event)
      parsed = JSON.parse(output)

      parsed["attributes"]["custom"].as_s.should eq("value")
    end

    it "includes exception when present" do
      formatter = Logit::Formatter::JSON.new

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
      event.exception = Logit::ExceptionInfo.new("TestError", "test message")

      output = formatter.format(event)
      parsed = JSON.parse(output)

      parsed["exception"]["type"].as_s.should eq("TestError")
      parsed["exception"]["message"].as_s.should eq("test message")
    end
  end
end
