require "../spec_helper"
require "../../src/logit/namespace_binding"

describe Logit::NamespaceBinding do
  describe "#initialize" do
    it "creates a binding with pattern and level" do
      binding = Logit::NamespaceBinding.new("MyLib::*", Logit::LogLevel::Debug)
      binding.pattern.should eq("MyLib::*")
      binding.level.should eq(Logit::LogLevel::Debug)
    end

    it "raises on empty pattern" do
      expect_raises(ArgumentError, "Pattern cannot be empty") do
        Logit::NamespaceBinding.new("", Logit::LogLevel::Info)
      end
    end

    it "raises on pattern without :: separator" do
      expect_raises(ArgumentError, "Pattern must use '::' separator") do
        Logit::NamespaceBinding.new("MyLib.HTTP", Logit::LogLevel::Info)
      end
    end

    it "raises on pattern with consecutive :::" do
      expect_raises(ArgumentError, "Pattern cannot contain ':::'") do
        Logit::NamespaceBinding.new("MyLib:::HTTP", Logit::LogLevel::Info)
      end
    end
  end

  describe "#matches?" do
    it "matches exact namespaces" do
      binding = Logit::NamespaceBinding.new("MyLib::HTTP", Logit::LogLevel::Debug)

      binding.matches?("MyLib::HTTP").should be_true
      binding.matches?("MyLib::DB").should be_false
    end

    it "matches single-component wildcards" do
      binding = Logit::NamespaceBinding.new("MyLib::HTTP::*", Logit::LogLevel::Debug)

      binding.matches?("MyLib::HTTP::Client").should be_true
      binding.matches?("MyLib::HTTP::Server").should be_true
      binding.matches?("MyLib::DB::Connection").should be_false
      binding.matches?("MyLib::HTTP").should be_false
    end

    it "matches multi-component wildcards" do
      binding = Logit::NamespaceBinding.new("MyLib::**", Logit::LogLevel::Debug)

      binding.matches?("MyLib::HTTP::Client").should be_true
      binding.matches?("MyLib::DB::Connection").should be_true
      binding.matches?("OtherLib::HTTP").should be_false
    end
  end
end
