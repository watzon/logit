require "../../spec_helper"
require "../../../src/logit"
require "json"

describe Logit::Backend::OTLP do
  describe "Config" do
    it "creates config with defaults" do
      config = Logit::Backend::OTLP::Config.new("http://localhost:4318/v1/logs")
      config.endpoint.should eq("http://localhost:4318/v1/logs")
      config.batch_size.should eq(512)
      config.flush_interval.should eq(5.seconds)
      config.headers.should be_empty
      config.timeout.should eq(30.seconds)
      config.resource_attributes.should be_empty
      config.scope_name.should eq("logit")
      config.scope_version.should eq(Logit::VERSION)
    end

    it "creates config with custom values" do
      config = Logit::Backend::OTLP::Config.new(
        endpoint: "https://example.com/v1/logs",
        batch_size: 100,
        flush_interval: 10.seconds,
        headers: {"Authorization" => "Bearer token"},
        timeout: 60.seconds,
        resource_attributes: {"service.name" => "test-app"},
        scope_name: "custom-scope",
        scope_version: "1.0.0"
      )
      config.endpoint.should eq("https://example.com/v1/logs")
      config.batch_size.should eq(100)
      config.flush_interval.should eq(10.seconds)
      config.headers.should eq({"Authorization" => "Bearer token"})
      config.timeout.should eq(60.seconds)
      config.resource_attributes.should eq({"service.name" => "test-app"})
      config.scope_name.should eq("custom-scope")
      config.scope_version.should eq("1.0.0")
    end
  end

  describe "PayloadBuilder" do
    it "builds valid OTLP JSON structure" do
      builder = Logit::Backend::OTLP::PayloadBuilder.new(
        resource_attributes: {"service.name" => "test-app"},
        scope_name: "logit",
        scope_version: "0.1.0"
      )

      event = Logit::Event.new(
        trace_id: "abcdef1234567890abcdef1234567890",
        span_id: "1234567890abcdef",
        name: "test.method",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 42,
        method_name: "test_method",
        class_name: "TestClass"
      )
      event.duration_ms = 100_i64

      payload = builder.build([event])
      json = JSON.parse(payload)

      # Check top-level structure
      json["resourceLogs"].should be_a(JSON::Any)
      json["resourceLogs"].as_a.size.should eq(1)

      resource_log = json["resourceLogs"][0]

      # Check resource attributes
      resource = resource_log["resource"]["attributes"].as_a
      resource.any? { |attr| attr["key"] == "service.name" && attr["value"]["stringValue"] == "test-app" }.should be_true

      # Check scope
      scope_log = resource_log["scopeLogs"][0]
      scope_log["scope"]["name"].should eq("logit")
      scope_log["scope"]["version"].should eq("0.1.0")

      # Check log record
      log_record = scope_log["logRecords"][0]
      log_record["severityNumber"].should eq(9) # INFO
      log_record["severityText"].should eq("INFO")
      log_record["body"]["stringValue"].should eq("test.method")
      log_record["traceId"].should eq("ABCDEF1234567890ABCDEF1234567890")
      log_record["spanId"].should eq("1234567890ABCDEF")
      log_record["flags"].should eq(1)

      # Check attributes
      attrs = log_record["attributes"].as_a
      attrs.any? { |a| a["key"] == "code.function" && a["value"]["stringValue"] == "test_method" }.should be_true
      attrs.any? { |a| a["key"] == "code.namespace" && a["value"]["stringValue"] == "TestClass" }.should be_true
      attrs.any? { |a| a["key"] == "code.filepath" && a["value"]["stringValue"] == "test.cr" }.should be_true
      attrs.any? { |a| a["key"] == "code.lineno" && a["value"]["intValue"] == "42" }.should be_true
      attrs.any? { |a| a["key"] == "logit.duration_ms" && a["value"]["intValue"] == "100" }.should be_true
    end

    it "maps log levels to correct severity numbers" do
      builder = Logit::Backend::OTLP::PayloadBuilder.new(
        resource_attributes: {} of String => String,
        scope_name: "logit",
        scope_version: "0.1.0"
      )

      {
        Logit::LogLevel::Trace => 1,
        Logit::LogLevel::Debug => 5,
        Logit::LogLevel::Info  => 9,
        Logit::LogLevel::Warn  => 13,
        Logit::LogLevel::Error => 17,
        Logit::LogLevel::Fatal => 21,
      }.each do |level, expected_severity|
        event = Logit::Event.new(
          trace_id: "abcdef1234567890abcdef1234567890",
          span_id: "1234567890abcdef",
          name: "test",
          level: level,
          code_file: "test.cr",
          code_line: 1,
          method_name: "test",
          class_name: "Test"
        )

        payload = builder.build([event])
        json = JSON.parse(payload)
        log_record = json["resourceLogs"][0]["scopeLogs"][0]["logRecords"][0]
        log_record["severityNumber"].should eq(expected_severity)
        log_record["severityText"].should eq(level.to_s.upcase)
      end
    end

    it "includes exception info when present" do
      builder = Logit::Backend::OTLP::PayloadBuilder.new(
        resource_attributes: {} of String => String,
        scope_name: "logit",
        scope_version: "0.1.0"
      )

      event = Logit::Event.new(
        trace_id: "abcdef1234567890abcdef1234567890",
        span_id: "1234567890abcdef",
        name: "test",
        level: Logit::LogLevel::Error,
        code_file: "test.cr",
        code_line: 1,
        method_name: "test",
        class_name: "Test"
      )
      event.exception = Logit::ExceptionInfo.new(
        type: "RuntimeError",
        message: "Something went wrong",
        stacktrace: ["line1", "line2"]
      )

      payload = builder.build([event])
      json = JSON.parse(payload)
      attrs = json["resourceLogs"][0]["scopeLogs"][0]["logRecords"][0]["attributes"].as_a

      attrs.any? { |a| a["key"] == "exception.type" && a["value"]["stringValue"] == "RuntimeError" }.should be_true
      attrs.any? { |a| a["key"] == "exception.message" && a["value"]["stringValue"] == "Something went wrong" }.should be_true
      attrs.any? { |a| a["key"] == "exception.stacktrace" && a["value"]["stringValue"] == "line1\nline2" }.should be_true
    end

    it "includes user-defined attributes" do
      builder = Logit::Backend::OTLP::PayloadBuilder.new(
        resource_attributes: {} of String => String,
        scope_name: "logit",
        scope_version: "0.1.0"
      )

      event = Logit::Event.new(
        trace_id: "abcdef1234567890abcdef1234567890",
        span_id: "1234567890abcdef",
        name: "test",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 1,
        method_name: "test",
        class_name: "Test"
      )
      event.attributes.set("user.id", "12345")
      event.attributes.set("http.status_code", 200_i64)
      event.attributes.set("request.success", true)

      payload = builder.build([event])
      json = JSON.parse(payload)
      attrs = json["resourceLogs"][0]["scopeLogs"][0]["logRecords"][0]["attributes"].as_a

      attrs.any? { |a| a["key"] == "user.id" && a["value"]["stringValue"] == "12345" }.should be_true
      attrs.any? { |a| a["key"] == "http.status_code" && a["value"]["intValue"] == "200" }.should be_true
      attrs.any? { |a| a["key"] == "request.success" && a["value"]["boolValue"] == true }.should be_true
    end
  end

  describe "BatchProcessor" do
    it "buffers events until batch size is reached" do
      flushed_events = [] of Array(Logit::Event)

      processor = Logit::Backend::OTLP::BatchProcessor.new(
        batch_size: 3,
        flush_interval: 100.milliseconds # Short interval for testing
      ) do |events|
        flushed_events << events.dup
      end

      processor.start

      # Add 2 events - should not flush yet
      2.times do |i|
        event = Logit::Event.new(
          trace_id: "trace#{i}",
          span_id: "span#{i}",
          name: "event#{i}",
          level: Logit::LogLevel::Info,
          code_file: "test.cr",
          code_line: i,
          method_name: "test",
          class_name: "Test"
        )
        processor.add(event)
      end

      flushed_events.size.should eq(0)

      # Add 3rd event - should trigger flush
      event = Logit::Event.new(
        trace_id: "trace2",
        span_id: "span2",
        name: "event2",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 2,
        method_name: "test",
        class_name: "Test"
      )
      processor.add(event)

      # Give it a moment to flush
      sleep 10.milliseconds

      flushed_events.size.should eq(1)
      flushed_events[0].size.should eq(3)

      processor.stop
    end

    it "flushes remaining events on stop" do
      flushed_events = [] of Array(Logit::Event)

      processor = Logit::Backend::OTLP::BatchProcessor.new(
        batch_size: 10,
        flush_interval: 100.milliseconds
      ) do |events|
        flushed_events << events.dup
      end

      processor.start

      # Add some events
      2.times do |i|
        event = Logit::Event.new(
          trace_id: "trace#{i}",
          span_id: "span#{i}",
          name: "event#{i}",
          level: Logit::LogLevel::Info,
          code_file: "test.cr",
          code_line: i,
          method_name: "test",
          class_name: "Test"
        )
        processor.add(event)
      end

      flushed_events.size.should eq(0)

      processor.stop

      flushed_events.size.should eq(1)
      flushed_events[0].size.should eq(2)
    end

    it "flushes on explicit flush call" do
      flushed_events = [] of Array(Logit::Event)

      processor = Logit::Backend::OTLP::BatchProcessor.new(
        batch_size: 10,
        flush_interval: 100.milliseconds
      ) do |events|
        flushed_events << events.dup
      end

      processor.start

      event = Logit::Event.new(
        trace_id: "trace",
        span_id: "span",
        name: "event",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 1,
        method_name: "test",
        class_name: "Test"
      )
      processor.add(event)

      flushed_events.size.should eq(0)

      processor.flush

      flushed_events.size.should eq(1)
      flushed_events[0].size.should eq(1)

      processor.stop
    end
  end

  describe "#initialize via config" do
    it "configures OTLP backend through Logit.configure" do
      config = Logit::Config.new
      backend = config.otlp(
        "http://localhost:4318/v1/logs",
        level: Logit::LogLevel::Debug,
        batch_size: 100,
        resource_attributes: {"service.name" => "test"}
      )

      backend.should be_a(Logit::Backend::OTLP)
      backend.name.should eq("otlp")
      backend.level.should eq(Logit::LogLevel::Debug)

      # Close to stop background fiber
      backend.close
    end
  end
end
