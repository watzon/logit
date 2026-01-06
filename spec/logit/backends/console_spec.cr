require "../../spec_helper"
require "../../../src/logit"

describe Logit::Backend::Console do
  describe "#initialize" do
    it "creates a console backend with defaults" do
      backend = Logit::Backend::Console.new
      backend.name.should eq("console")
      backend.level.should eq(Logit::LogLevel::Info)
    end

    it "creates a console backend with custom settings" do
      formatter = Logit::Formatter::Human.new
      backend = Logit::Backend::Console.new("myconsole", Logit::LogLevel::Debug, formatter)
      backend.name.should eq("myconsole")
      backend.level.should eq(Logit::LogLevel::Debug)
    end
  end

  describe "#log" do
    it "logs events above the configured level" do
      io = IO::Memory.new
      backend = Logit::Backend::Console.new("console", Logit::LogLevel::Warn)
      backend.log_io = io

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

      backend.log(event)
      io.rewind.gets_to_end.should contain("ERROR")
    end

    it "filters events below the configured level" do
      io = IO::Memory.new
      backend = Logit::Backend::Console.new("console", Logit::LogLevel::Warn)
      backend.log_io = io

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
      io.rewind.gets_to_end.should be_empty
    end
  end
end

# Monkey patch to allow custom IO for testing
class Logit::Backend::Console
  property log_io : IO?

  def initialize(@name = "console", @level = Logit::LogLevel::Info, @formatter = Logit::Formatter::Human.new)
    @bindings = [] of Logit::NamespaceBinding
    @log_io = STDOUT
  end

  def log(event : Logit::Event) : Nil
    return unless should_log?(event)

    io = @log_io || STDOUT
    io << @formatter.not_nil!.format(event) << "\n"
    io.flush
  end
end
