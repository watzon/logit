require "../../spec_helper"
require "../../../src/logit"

describe Logit::Event::Attributes do
  describe "#initialize" do
    it "creates an empty attributes container" do
      attrs = Logit::Event::Attributes.new
      attrs.values.should be_empty
    end
  end

  describe "#set" do
    it "stores string values" do
      attrs = Logit::Event::Attributes.new
      attrs.set("key", "value")
      attrs.get("key").should_not be_nil
      attrs.get("key").not_nil!.as_s.should eq("value")
    end

    it "stores integer values" do
      attrs = Logit::Event::Attributes.new
      attrs.set("count", 42)
      attrs.get("count").not_nil!.as_i.should eq(42)
    end

    it "stores float values" do
      attrs = Logit::Event::Attributes.new
      attrs.set("price", 19.99)
      attrs.get("price").not_nil!.as_f.should eq(19.99)
    end

    it "stores boolean values" do
      attrs = Logit::Event::Attributes.new
      attrs.set("active", true)
      attrs.get("active").not_nil!.as_bool.should be_true
    end

    it "stores nil values" do
      attrs = Logit::Event::Attributes.new
      attrs.set("nothing", nil)
      attrs.get("nothing").should be_nil
    end

    it "overwrites existing keys" do
      attrs = Logit::Event::Attributes.new
      attrs.set("key", "value1")
      attrs.set("key", "value2")
      attrs.get("key").not_nil!.as_s.should eq("value2")
    end
  end

  describe "#set_any" do
    it "stores arbitrary JSON-serializable types" do
      attrs = Logit::Event::Attributes.new
      attrs.set_any("obj", {name: "test", value: 123})
      result = attrs.get("obj").not_nil!.as_h
      result["name"].not_nil!.as_s.should eq("test")
      result["value"].not_nil!.as_i.should eq(123)
    end
  end

  describe "#set_object" do
    it "stores objects as nested attributes" do
      attrs = Logit::Event::Attributes.new
      attrs.set_object("metadata", version: "1.0.0", environment: "production")
      result = attrs.get("metadata").not_nil!.as_h
      result["version"].not_nil!.as_s.should eq("1.0.0")
      result["environment"].not_nil!.as_s.should eq("production")
    end
  end

  describe "#set_array" do
    it "stores arrays of values" do
      attrs = Logit::Event::Attributes.new
      attrs.set_array("tags", "important", "production", "v2")
      result = attrs.get("tags").not_nil!.as_a
      result.map(&.as_s).should eq(["important", "production", "v2"])
    end
  end

  describe "#get" do
    it "returns nil for non-existent keys" do
      attrs = Logit::Event::Attributes.new
      attrs.get("nonexistent").should be_nil
    end

    it "returns JSON::Any for existing keys" do
      attrs = Logit::Event::Attributes.new
      attrs.set("key", "value")
      result = attrs.get("key")
      result.should be_a(JSON::Any)
      result.not_nil!.as_s.should eq("value")
    end
  end

  describe "#to_json" do
    it "serializes to JSON" do
      attrs = Logit::Event::Attributes.new
      attrs.set("string", "value")
      attrs.set("number", 42)
      attrs.set("bool", true)

      json = attrs.to_json
      parsed = JSON.parse(json)
      parsed["string"].as_s.should eq("value")
      parsed["number"].as_i.should eq(42)
      parsed["bool"].as_bool.should be_true
    end
  end
end
