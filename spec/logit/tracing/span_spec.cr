require "../../spec_helper"
require "../../../src/logit"

describe Logit::Span do
  describe "#initialize" do
    it "creates a span with required fields" do
      span = Logit::Span.new("test.operation")

      span.name.should eq("test.operation")
      span.span_id.size.should eq(16)  # W3C span ID is 16 hex chars
      span.trace_id.size.should eq(32) # W3C trace ID is 32 hex chars
      span.start_time.should be_a(Time)
      span.end_time.should be_nil
      span.attributes.should be_a(Logit::Event::Attributes)
      span.exception.should be_nil
    end

    it "generates new trace ID when no parent exists" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      span = Logit::Span.new("test.operation")
      span.trace_id.size.should eq(32)
    end

    it "inherits trace ID from parent span" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      parent = Logit::Span.new("parent")
      Logit::Span.push(parent)

      child = Logit::Span.new("child")
      child.trace_id.should eq(parent.trace_id)
      child.parent_span_id.should eq(parent.span_id)

      # Cleanup
      Logit::Span.pop
      Logit::Span.pop
    end
  end

  describe "fiber-local stack" do
    it "maintains separate stacks per fiber" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      span1 = Logit::Span.new("span1")
      Logit::Span.push(span1)

      channel = Channel(Nil).new
      spawn do
        span2 = Logit::Span.new("span2")
        Logit::Span.push(span2)
        Logit::Span.current.should eq(span2)
        Logit::Span.pop
        channel.send(nil)
      end

      channel.receive

      Logit::Span.current.should eq(span1)
      Logit::Span.pop
      Logit::Span.current?.should be_nil
    end

    it "pushes and pops spans correctly" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      span1 = Logit::Span.new("span1")
      span2 = Logit::Span.new("span2")

      Logit::Span.push(span1)
      Logit::Span.current.should eq(span1)

      Logit::Span.push(span2)
      Logit::Span.current.should eq(span2)

      Logit::Span.pop.should eq(span2)
      Logit::Span.current.should eq(span1)

      Logit::Span.pop.should eq(span1)
      Logit::Span.current?.should be_nil
    end
  end

  describe ".current?" do
    it "returns nil when no span is active" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      Logit::Span.current?.should be_nil
    end

    it "returns the current span when one is active" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      span = Logit::Span.new("test")
      Logit::Span.push(span)
      Logit::Span.current?.should eq(span)
      Logit::Span.pop
    end
  end

  describe ".current" do
    it "raises when no span is active" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      expect_raises(Exception, "No active span") do
        Logit::Span.current
      end
    end

    it "returns the current span when one is active" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      span = Logit::Span.new("test")
      Logit::Span.push(span)
      Logit::Span.current.should eq(span)
      Logit::Span.pop
    end
  end

  describe "#to_event" do
    it "creates an event from the span" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      span = Logit::Span.new("test.operation")
      sleep 1.milliseconds # Ensure at least 1ms duration
      span.end_time = Time.utc

      event = span.to_event(
        trace_id: span.trace_id,
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass"
      )

      event.trace_id.should eq(span.trace_id)
      event.span_id.should eq(span.span_id)
      event.parent_span_id.should eq(span.parent_span_id)
      event.name.should eq("test.operation")
      event.duration_ms.should be > 0
    end

    it "includes span attributes in the event" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      span = Logit::Span.new("test.operation")
      span.attributes.set("custom", "value")
      span.end_time = Time.utc

      event = span.to_event(
        trace_id: span.trace_id,
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass"
      )

      event.attributes.get("custom").not_nil!.as_s.should eq("value")
    end

    it "includes span exception in the event" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      span = Logit::Span.new("test.operation")
      span.exception = Logit::ExceptionInfo.new("TestError", "test error")
      span.end_time = Time.utc

      event = span.to_event(
        trace_id: span.trace_id,
        level: Logit::LogLevel::Error,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass"
      )

      event.exception.should_not be_nil
      event.exception.not_nil!.type.should eq("TestError")
    end
  end
end
