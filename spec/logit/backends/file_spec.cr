require "../../spec_helper"
require "../../../src/logit"

describe Logit::Backend::File do
  describe "#initialize" do
    it "creates a file backend" do
      path = "/tmp/logtest-#{Random::Secure.hex(8)}.log"
      begin
        backend = Logit::Backend::File.new(path, "file", Logit::LogLevel::Info)
        backend.name.should eq("file")
        backend.level.should eq(Logit::LogLevel::Info)
      ensure
        File.delete(path) if File.exists?(path)
      end
    end
  end

  describe "#log" do
    it "writes events to the file as JSON" do
      path = "/tmp/logtest-#{Random::Secure.hex(8)}.log"
      begin
        backend = Logit::Backend::File.new(path, "file", Logit::LogLevel::Info)

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

        backend.log(event)
        backend.close

        content = File.read(path)
        parsed = JSON.parse(content)
        parsed["trace_id"].as_s.should eq("trace123")
        parsed["name"].as_s.should eq("test.event")
      ensure
        File.delete(path) if File.exists?(path)
      end
    end

    it "filters events below the configured level" do
      path = "/tmp/logtest-#{Random::Secure.hex(8)}.log"
      begin
        backend = Logit::Backend::File.new(path, "file", Logit::LogLevel::Warn)

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

        backend.log(event)
        backend.close

        File.size(path).should eq(0)
      ensure
        File.delete(path) if File.exists?(path)
      end
    end
  end

  describe "#close" do
    it "closes the file handle" do
      path = "/tmp/logtest-#{Random::Secure.hex(8)}.log"
      begin
        backend = Logit::Backend::File.new(path)
        backend.close

        # File should be closed, attempting to log should fail
        expect_raises(IO::Error) do
          backend.log(Logit::Event.new(
            trace_id: "trace123",
            span_id: "span456",
            name: "test.event",
            level: Logit::LogLevel::Info,
            code_file: "test.cr",
            code_line: 10,
            method_name: "test_method",
            class_name: "TestClass"
          ))
        end
      ensure
        File.delete(path) if File.exists?(path)
      end
    end
  end
end
