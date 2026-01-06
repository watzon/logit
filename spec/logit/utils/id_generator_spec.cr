require "../../spec_helper"
require "../../../src/logit"

describe Logit::Utils::IDGenerator do
  describe ".trace_id" do
    it "generates a 32-character hex string" do
      trace_id = Logit::Utils::IDGenerator.trace_id
      trace_id.size.should eq(32)
      trace_id.matches?(/^[0-9a-f]{32}$/).should be_true
    end

    it "generates different IDs on multiple calls" do
      ids = [] of String
      10.times do
        ids << Logit::Utils::IDGenerator.trace_id
      end
      ids.uniq.size.should be > 1 # At least some variety
    end
  end

  describe ".span_id" do
    it "generates a 16-character hex string" do
      span_id = Logit::Utils::IDGenerator.span_id
      span_id.size.should eq(16)
      span_id.matches?(/^[0-9a-f]{16}$/).should be_true
    end

    it "generates different IDs on multiple calls" do
      ids = [] of String
      10.times do
        ids << Logit::Utils::IDGenerator.span_id
      end
      ids.uniq.size.should be > 1 # At least some variety
    end
  end
end
