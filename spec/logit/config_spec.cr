require "../spec_helper"
require "../../src/logit"

describe Logit::Config do
  describe "#initialize" do
    it "creates an empty configuration" do
      config = Logit::Config.new
      config.tracers.should be_empty
      config.default_tracer_name.should eq("default")
    end
  end

  describe ".configure" do
    it "yields a new configuration" do
      Logit::Config.configure do |config|
        config.should be_a(Logit::Config)
      end
    end
  end

  describe "#console" do
    it "adds a console backend" do
      config = Logit::Config.new
      backend = config.console(Logit::LogLevel::Debug)

      backend.should be_a(Logit::Backend::Console)
      tracer = config.tracers[config.default_tracer_name]?
      tracer.should_not be_nil
      tracer.not_nil!.backends.size.should be >= 1
    end

    it "accepts a custom formatter" do
      config = Logit::Config.new
      formatter = Logit::Formatter::JSON.new
      backend = config.console(Logit::LogLevel::Info, formatter)

      backend.should be_a(Logit::Backend::Console)
      tracer = config.tracers[config.default_tracer_name]?
      tracer.should_not be_nil
      tracer.not_nil!.backends.size.should be >= 1
    end
  end

  describe "#file" do
    it "adds a file backend" do
      path = "/tmp/logtest-#{Random::Secure.hex(8)}.log"
      begin
        config = Logit::Config.new
        backend = config.file(path, Logit::LogLevel::Info)

        backend.should be_a(Logit::Backend::File)
        tracer = config.tracers[config.default_tracer_name]?
        tracer.should_not be_nil
        tracer.not_nil!.backends.size.should be >= 1
      ensure
        File.delete(path) if File.exists?(path)
      end
    end
  end

  describe "#add_tracer" do
    it "adds a custom tracer" do
      config = Logit::Config.new
      tracer = Logit::Tracer.new("custom")

      config.add_tracer("custom", tracer)
      config.tracers["custom"]?.should eq(tracer)
    end
  end

  describe "#add_backend" do
    it "adds a backend to the default tracer" do
      config = Logit::Config.new
      backend = Logit::Backend::Console.new("console")

      config.add_backend(backend)

      tracer = config.tracers[config.default_tracer_name]?
      tracer.should_not be_nil
      tracer.not_nil!.backends.size.should eq(1)
    end

    it "creates default tracer if it doesn't exist" do
      config = Logit::Config.new
      backend = Logit::Backend::Console.new("console")

      config.add_backend(backend)

      tracer = config.tracers[config.default_tracer_name]?
      tracer.should_not be_nil
      tracer.not_nil!.name.should eq(config.default_tracer_name)
    end
  end

  describe "#bind" do
    it "binds namespace to backend" do
      config = Logit::Config.new
      backend = Logit::Backend::Console.new("console", Logit::LogLevel::Info)

      config.bind("MyLib::*", Logit::LogLevel::Debug, backend)

      backend.bindings.size.should eq(1)
      backend.bindings[0].level.should eq(Logit::LogLevel::Debug)
    end

    it "chains with console method" do
      config = Logit::Config.new
      backend = config.console(Logit::LogLevel::Info)
      config.bind("MyLib::*", Logit::LogLevel::Debug, backend)

      backend.bindings.size.should eq(1)
    end

    it "chains with file method" do
      path = "/tmp/logtest-#{Random::Secure.hex(8)}.log"
      begin
        config = Logit::Config.new
        backend = config.file(path, Logit::LogLevel::Info)
        config.bind("MyLib::**", Logit::LogLevel::Warn, backend)

        backend.bindings.size.should eq(1)
        backend.bindings[0].pattern.should eq("MyLib::**")
      ensure
        File.delete(path) if File.exists?(path)
      end
    end
  end

  describe "#build" do
    it "sets the default tracer" do
      config = Logit::Config.new
      config.console(Logit::LogLevel::Info)
      config.build

      Logit::Tracer.default.should be_a(Logit::Tracer)
    end
  end

  describe "Logit.configure" do
    it "configures and builds in one call" do
      # Reset default tracer
      Logit::Tracer.default = Logit::Tracer.new("default")

      Logit.configure do |config|
        config.console(Logit::LogLevel::Debug)
      end

      Logit::Tracer.default.backends.size.should be >= 1

      # Reset for other tests
      Logit::Tracer.default = Logit::Tracer.new("default")
    end
  end
end
