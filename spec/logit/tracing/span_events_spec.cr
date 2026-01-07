require "../../spec_helper"

describe "Logit::Span events" do
  describe "#add_event" do
    it "adds an event with name only" do
      span = Logit::Span.new("test_span")
      span.add_event("checkpoint")

      span.events.size.should eq(1)
      span.events[0].name.should eq("checkpoint")
      span.events[0].attributes.values.empty?.should be_true
    end

    it "adds an event with string attributes" do
      span = Logit::Span.new("test_span")
      span.add_event("file.opened", path: "/tmp/file.txt")

      span.events.size.should eq(1)
      span.events[0].name.should eq("file.opened")
      span.events[0].attributes.get("path").should eq("/tmp/file.txt")
    end

    it "adds an event with numeric attributes" do
      span = Logit::Span.new("test_span")
      span.add_event("query.complete", rows: 42, duration_ms: 150)

      span.events.size.should eq(1)
      span.events[0].attributes.get("rows").should eq(42_i64)
      span.events[0].attributes.get("duration_ms").should eq(150_i64)
    end

    it "adds an event with boolean attributes" do
      span = Logit::Span.new("test_span")
      span.add_event("cache.access", hit: true)

      span.events.size.should eq(1)
      span.events[0].attributes.get("hit").should eq(true)
    end

    it "adds multiple events in order" do
      span = Logit::Span.new("test_span")
      span.add_event("step.1")
      span.add_event("step.2")
      span.add_event("step.3")

      span.events.size.should eq(3)
      span.events[0].name.should eq("step.1")
      span.events[1].name.should eq("step.2")
      span.events[2].name.should eq("step.3")
    end

    it "records timestamp for each event" do
      span = Logit::Span.new("test_span")

      before = Time.utc
      span.add_event("timed_event")
      after = Time.utc

      span.events[0].timestamp.should be >= before
      span.events[0].timestamp.should be <= after
    end
  end

  describe "#to_event" do
    it "includes span events in the resulting event" do
      span = Logit::Span.new("test_span")
      span.add_event("event.1", key: "value1")
      span.add_event("event.2", key: "value2")
      span.end_time = Time.utc

      event = span.to_event(
        trace_id: span.trace_id,
        level: Logit::LogLevel::Info,
        code_file: __FILE__,
        code_line: __LINE__,
        method_name: "test",
        class_name: "Test"
      )

      event.span_events.size.should eq(2)
      event.span_events[0].name.should eq("event.1")
      event.span_events[1].name.should eq("event.2")
    end
  end
end

describe Logit::SpanEvent do
  describe "#to_json" do
    it "serializes to JSON correctly" do
      attrs = Logit::Event::Attributes.new
      attrs.set("key", "value")
      attrs.set("count", 42_i64)

      event = Logit::SpanEvent.new(
        name: "test.event",
        timestamp: Time.utc(2025, 1, 7, 12, 0, 0),
        attributes: attrs
      )

      json = event.to_json
      parsed = JSON.parse(json)

      parsed["name"].should eq("test.event")
      parsed["timestamp"].as_s.should contain("2025-01-07")
      parsed["attributes"]["key"].should eq("value")
      parsed["attributes"]["count"].should eq(42)
    end

    it "omits attributes field when empty" do
      event = Logit::SpanEvent.new(
        name: "empty.event",
        timestamp: Time.utc,
        attributes: Logit::Event::Attributes.new
      )

      json = event.to_json
      parsed = JSON.parse(json)

      parsed["name"].should eq("empty.event")
      parsed["attributes"]?.should be_nil
    end
  end
end
