require "../spec_helper"
require "../../src/logit"

describe Logit::LogLevel do
  describe "enum values" do
    it "has all standard log levels" do
      Logit::LogLevel::Trace.value.should eq(0)
      Logit::LogLevel::Debug.value.should eq(1)
      Logit::LogLevel::Info.value.should eq(2)
      Logit::LogLevel::Warn.value.should eq(3)
      Logit::LogLevel::Error.value.should eq(4)
      Logit::LogLevel::Fatal.value.should eq(5)
    end
  end

  describe "comparison operators" do
    it "compares levels correctly" do
      (Logit::LogLevel::Debug < Logit::LogLevel::Info).should be_true
      (Logit::LogLevel::Info < Logit::LogLevel::Warn).should be_true
      (Logit::LogLevel::Warn < Logit::LogLevel::Error).should be_true
      (Logit::LogLevel::Error < Logit::LogLevel::Fatal).should be_true

      (Logit::LogLevel::Info > Logit::LogLevel::Debug).should be_true
      (Logit::LogLevel::Fatal > Logit::LogLevel::Error).should be_true

      (Logit::LogLevel::Info >= Logit::LogLevel::Info).should be_true
      (Logit::LogLevel::Info >= Logit::LogLevel::Debug).should be_true

      (Logit::LogLevel::Info <= Logit::LogLevel::Info).should be_true
      (Logit::LogLevel::Info <= Logit::LogLevel::Warn).should be_true
    end
  end

  describe "string representation" do
    it "converts to lowercase strings" do
      Logit::LogLevel::Trace.to_s.should eq("trace")
      Logit::LogLevel::Debug.to_s.should eq("debug")
      Logit::LogLevel::Info.to_s.should eq("info")
      Logit::LogLevel::Warn.to_s.should eq("warn")
      Logit::LogLevel::Error.to_s.should eq("error")
      Logit::LogLevel::Fatal.to_s.should eq("fatal")
    end
  end

  describe "from_string" do
    it "parses lowercase level names" do
      Logit::LogLevel.parse("trace").should eq(Logit::LogLevel::Trace)
      Logit::LogLevel.parse("debug").should eq(Logit::LogLevel::Debug)
      Logit::LogLevel.parse("info").should eq(Logit::LogLevel::Info)
      Logit::LogLevel.parse("warn").should eq(Logit::LogLevel::Warn)
      Logit::LogLevel.parse("error").should eq(Logit::LogLevel::Error)
      Logit::LogLevel.parse("fatal").should eq(Logit::LogLevel::Fatal)
    end

    it "parses uppercase level names" do
      Logit::LogLevel.parse("TRACE").should eq(Logit::LogLevel::Trace)
      Logit::LogLevel.parse("DEBUG").should eq(Logit::LogLevel::Debug)
      Logit::LogLevel.parse("INFO").should eq(Logit::LogLevel::Info)
      Logit::LogLevel.parse("WARN").should eq(Logit::LogLevel::Warn)
      Logit::LogLevel.parse("ERROR").should eq(Logit::LogLevel::Error)
      Logit::LogLevel.parse("FATAL").should eq(Logit::LogLevel::Fatal)
    end

    it "parses mixed case level names" do
      Logit::LogLevel.parse("Info").should eq(Logit::LogLevel::Info)
      Logit::LogLevel.parse("WaRn").should eq(Logit::LogLevel::Warn)
    end

    it "raises on invalid level names" do
      expect_raises(ArgumentError) do
        Logit::LogLevel.parse("invalid")
      end
    end
  end
end
