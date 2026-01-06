require "../../spec_helper"
require "../../../src/logit"

describe Logit::Tracer do
  describe "#initialize" do
    it "creates a tracer with a name" do
      tracer = Logit::Tracer.new("test")
      tracer.name.should eq("test")
      tracer.backends.should be_empty
    end

    it "creates a tracer with backends" do
      backend = Logit::Backend::Console.new("console", Logit::LogLevel::Info)
      tracer = Logit::Tracer.new("test")
      tracer.add_backend(backend)
      tracer.backends.size.should eq(1)
    end
  end

  describe "#add_backend" do
    it "adds a backend to the tracer" do
      tracer = Logit::Tracer.new("test")
      backend = Logit::Backend::Console.new("console", Logit::LogLevel::Info)

      tracer.add_backend(backend)
      tracer.backends.size.should eq(1)
    end
  end

  describe "#remove_backend" do
    it "removes a backend by name" do
      backend1 = Logit::Backend::Console.new("console1", Logit::LogLevel::Info)
      backend2 = Logit::Backend::Console.new("console2", Logit::LogLevel::Info)
      tracer = Logit::Tracer.new("test")
      tracer.add_backend(backend1)
      tracer.add_backend(backend2)

      tracer.remove_backend("console1")
      tracer.backends.size.should eq(1)
      tracer.backends.first.name.should eq("console2")
    end
  end

  describe "#emit" do
    it "sends events to all backends" do
      # Create a test backend that captures events
      test_backend = Logit::TestBackend.new
      tracer = Logit::Tracer.new("test")
      tracer.add_backend(test_backend)

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

      tracer.emit(event)
      test_backend.logged_events.size.should eq(1)
      test_backend.logged_events.first.should eq(event)
    end

    it "isolates backend failures" do
      failing_backend = Logit::FailingBackend.new
      working_backend = Logit::TestBackend.new
      tracer = Logit::Tracer.new("test")
      tracer.add_backend(failing_backend)
      tracer.add_backend(working_backend)

      # Tracer created above

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

      tracer.emit(event)
      working_backend.logged_events.size.should eq(1)
    end
  end

  describe "#flush" do
    it "flushes all backends" do
      backend1 = Logit::TestBackend.new
      backend2 = Logit::TestBackend.new
      tracer = Logit::Tracer.new("test")
      tracer.add_backend(backend1)
      tracer.add_backend(backend2)

      # Tracer created above

      tracer.flush
      backend1.flushed_count.should eq(1)
      backend2.flushed_count.should eq(1)
    end
  end

  describe "#close" do
    it "closes all backends" do
      backend1 = Logit::TestBackend.new
      backend2 = Logit::TestBackend.new
      tracer = Logit::Tracer.new("test")
      tracer.add_backend(backend1)
      tracer.add_backend(backend2)

      # Tracer created above

      tracer.close
      backend1.closed_count.should eq(1)
      backend2.closed_count.should eq(1)
    end
  end

  describe ".default" do
    before_each do
      # Reset to a proper default tracer with console backend
      Logit::Tracer.default = Logit::Tracer.new("default").tap { |t| t.add_backend(Logit::Backend::Console.new) }
    end

    it "creates a default tracer with console backend" do
      tracer = Logit::Tracer.default
      tracer.name.should eq("default")
      tracer.backends.size.should be >= 1
    end

    it "returns the same instance across calls" do
      tracer1 = Logit::Tracer.default
      tracer2 = Logit::Tracer.default
      tracer1.should be(tracer2)
    end
  end

  describe ".default=" do
    it "sets a custom default tracer" do
      custom_tracer = Logit::Tracer.new("custom")
      Logit::Tracer.default = custom_tracer

      Logit::Tracer.default.should eq(custom_tracer)

      # Reset to avoid affecting other tests
      Logit::Tracer.default = Logit::Tracer.new("default")
    end
  end
end

# Test helper classes - defined inside Logit module for proper type resolution
module Logit
  class TestBackend < Backend
    property logged_events = [] of Event
    property flushed_count = 0
    property closed_count = 0

    def initialize(@name = "test", @level = LogLevel::Info)
      super(@name, @level)
    end

    def log(event : Event) : Nil
      @logged_events << event
    end

    def flush : Nil
      @flushed_count += 1
    end

    def close : Nil
      @closed_count += 1
    end
  end

  class FailingBackend < Backend
    def initialize(@name = "failing", @level = LogLevel::Info)
      super(@name, @level)
    end

    def log(event : Event) : Nil
      raise "Backend failure"
    end
  end
end
