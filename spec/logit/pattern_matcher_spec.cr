require "../spec_helper"
require "../../src/logit/pattern_matcher"

describe Logit::PatternMatcher do
  describe ".match?" do
    it "matches exact namespaces" do
      Logit::PatternMatcher.match?("MyLib::HTTP", "MyLib::HTTP").should be_true
      Logit::PatternMatcher.match?("MyLib::HTTP", "MyLib::DB").should be_false
    end

    it "matches single-component wildcards" do
      Logit::PatternMatcher.match?("MyLib::HTTP::Client", "MyLib::*::Client").should be_true
      Logit::PatternMatcher.match?("MyLib::HTTP::Client", "MyLib::*").should be_false
      Logit::PatternMatcher.match?("MyLib::HTTP::Client", "MyLib::HTTP::*").should be_true
      Logit::PatternMatcher.match?("MyLib::HTTP::Client", "MyLib::HTTP::*").should be_true
    end

    it "matches multi-component wildcards" do
      Logit::PatternMatcher.match?("MyLib::HTTP::Client", "MyLib::**").should be_true
      Logit::PatternMatcher.match?("MyLib::HTTP::Client", "**").should be_true
      Logit::PatternMatcher.match?("MyLib::HTTP::Client", "MyLib::**::Client").should be_true
      # MyLib::**::Client means "MyLib" + anything + "Client" at the END
      # MyLib::HTTP::Client::V2 ends with "V2", not "Client", so it shouldn't match
      Logit::PatternMatcher.match?("MyLib::HTTP::Client::V2", "MyLib::**::Client").should be_false
    end

    it "matches nested namespaces" do
      Logit::PatternMatcher.match?("MyApp::Services::Payment::Processor",
                                    "MyApp::Services::**").should be_true
      Logit::PatternMatcher.match?("MyApp::Services::Payment::Processor",
                                    "MyApp::**::Processor").should be_true
    end

    it "handles edge cases" do
      # Empty components in pattern
      Logit::PatternMatcher.match?("MyLib::HTTP", "::MyLib::HTTP").should be_true
      Logit::PatternMatcher.match?("MyLib::HTTP", "MyLib::HTTP::").should be_true

      # Single namespace component
      Logit::PatternMatcher.match?("MyLib", "MyLib").should be_true
      Logit::PatternMatcher.match?("MyLib", "*").should be_true
      Logit::PatternMatcher.match?("MyLib", "**").should be_true
    end

    it "handles non-matches correctly" do
      Logit::PatternMatcher.match?("MyLib::HTTP::Client", "OtherLib::*").should be_false
      # MyLib::*::* means "MyLib" + one component + one component = 3 total
      # MyLib::HTTP::Client has 3 components: "MyLib", "HTTP", "Client"
      # So this DOES match - changed expectation to reflect correct behavior
      Logit::PatternMatcher.match?("MyLib::HTTP::Client", "MyLib::*::*").should be_true
      Logit::PatternMatcher.match?("MyLib::HTTP", "MyLib::HTTP::*").should be_false
    end

    it "handles root namespace" do
      Logit::PatternMatcher.match?("MyLib", "**").should be_true
      Logit::PatternMatcher.match?("MyLib::HTTP", "**").should be_true
      Logit::PatternMatcher.match?("MyLib::HTTP::Client", "**").should be_true
    end
  end
end
