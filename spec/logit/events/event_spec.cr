require "../../spec_helper"
require "../../../src/logit"

describe Logit::Event do
  describe "#initialize" do
    it "creates an event with required fields" do
      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test.event",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass"
      )

      event.trace_id.should eq("trace123")
      event.span_id.should eq("span456")
      event.name.should eq("test.event")
      event.level.should eq(Logit::LogLevel::Info)
      event.code_file.should eq("test.cr")
      event.code_line.should eq(10)
      event.method_name.should eq("test_method")
      event.class_name.should eq("TestClass")
    end

    it "creates an event with optional parent_span_id" do
      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test.event",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass",
        parent_span_id: "parent789"
      )

      event.parent_span_id.should eq("parent789")
    end

    it "initializes with default values" do
      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test.event",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass"
      )

      event.timestamp.should be_a(Time)
      event.duration_ms.should eq(0)
      event.status.should eq(Logit::Status::Ok)
      event.attributes.should be_a(Logit::Event::Attributes)
      event.exception.should be_nil
    end
  end

  describe "#to_json" do
    it "serializes event to JSON" do
      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test.event",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass"
      )

      json = event.to_json
      parsed = JSON.parse(json)

      parsed["trace_id"].as_s.should eq("trace123")
      parsed["span_id"].as_s.should eq("span456")
      parsed["name"].as_s.should eq("test.event")
      parsed["level"].as_s.should eq("info")
      parsed["status"].as_s.should eq("ok")
    end

    it "includes attributes when present" do
      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test.event",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass"
      )

      event.attributes.set("custom", "value")

      json = event.to_json
      parsed = JSON.parse(json)
      parsed["attributes"]["custom"].as_s.should eq("value")
    end

    it "includes exception when present" do
      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "test.event",
        level: Logit::LogLevel::Error,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass"
      )

      event.exception = Logit::ExceptionInfo.new("TestError", "test message")

      json = event.to_json
      parsed = JSON.parse(json)
      parsed["exception"]["type"].as_s.should eq("TestError")
      parsed["exception"]["message"].as_s.should eq("test message")
    end
  end

  describe "OpenTelemetry helpers" do
    it "sets HTTP attributes" do
      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "http.request",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass"
      )

      event.set_http_method("GET")
      event.set_http_route("/api/users")
      event.set_http_status_code(200)

      event.attributes.get("http.method").not_nil!.as_s.should eq("GET")
      event.attributes.get("http.route").not_nil!.as_s.should eq("/api/users")
      event.attributes.get("http.status_code").not_nil!.as_i.should eq(200)
    end

    it "sets database attributes" do
      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "db.query",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass"
      )

      event.set_db_system("postgresql")
      event.set_db_name("mydb")
      event.set_db_operation("SELECT")

      event.attributes.get("db.system").not_nil!.as_s.should eq("postgresql")
      event.attributes.get("db.name").not_nil!.as_s.should eq("mydb")
      event.attributes.get("db.operation").not_nil!.as_s.should eq("SELECT")
    end

    it "sets user attributes" do
      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "user.action",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass"
      )

      event.set_user_id("user123")
      event.set_user_role("admin")

      event.attributes.get("enduser.id").not_nil!.as_s.should eq("user123")
      event.attributes.get("enduser.role").not_nil!.as_s.should eq("admin")
    end

    it "sets service attributes" do
      event = Logit::Event.new(
        trace_id: "trace123",
        span_id: "span456",
        name: "service.start",
        level: Logit::LogLevel::Info,
        code_file: "test.cr",
        code_line: 10,
        method_name: "test_method",
        class_name: "TestClass"
      )

      event.set_service_name("my-service")
      event.set_service_version("1.0.0")

      event.attributes.get("service.name").not_nil!.as_s.should eq("my-service")
      event.attributes.get("service.version").not_nil!.as_s.should eq("1.0.0")
    end
  end
end

describe Logit::Status do
  it "has Ok and Error values" do
    Logit::Status::Ok.to_s.should eq("ok")
    Logit::Status::Error.to_s.should eq("error")
  end
end

describe Logit::ExceptionInfo do
  describe "#from_exception" do
    it "creates info from a standard exception" do
      begin
        raise "Test exception"
      rescue ex
        info = Logit::ExceptionInfo.from_exception(ex)
        info.type.should eq("Exception")
        info.message.should eq("Test exception")
        info.stacktrace.should be_a(Array(String))
      end
    end
  end

  describe "#initialize" do
    it "creates exception info with fields" do
      info = Logit::ExceptionInfo.new("CustomError", "custom message", ["line1", "line2"])
      info.type.should eq("CustomError")
      info.message.should eq("custom message")
      info.stacktrace.should eq(["line1", "line2"])
    end
  end
end
