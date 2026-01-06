require "../spec_helper"
require "../../src/logit"

# Setup Logit for testing
Logit.configure do |config|
  config.console(Logit::LogLevel::Debug)
end

# Test class with instrumentation (defined at top level)
class TestCalculator
  include Logit::Instrumentation

  @[Logit::Log]
  def add(x : Int32, y : Int32) : Int32
    x + y
  end

  @[Logit::Log]
  def multiply(x : Int32, y : Int32) : Int32
    x * y
  end

  @[Logit::Log]
  def greet(name : String) : String
    "Hello, #{name}!"
  end

  @[Logit::Log]
  def no_args : String
    "no args"
  end

  @[Logit::Log]
  def raises_error : String
    raise "Test error"
  end

  @[Logit::Log]
  def nested_call : Int32
    add(5, 3)
  end

  # Call setup_instrumentation AFTER all methods are defined
  Logit.setup_instrumentation(TestCalculator)
end

# Additional test classes for annotation tests
class AnnotatedClass
  include Logit::Instrumentation

  @[Logit::Log]
  def test_method : String
    "test"
  end

  Logit.setup_instrumentation(AnnotatedClass)
end

class MultiAnnotated
  include Logit::Instrumentation

  @[Logit::Log]
  def method_one : Int32
    1
  end

  @[Logit::Log]
  def method_two : Int32
    2
  end

  @[Logit::Log]
  def method_three : Int32
    3
  end

  Logit.setup_instrumentation(MultiAnnotated)
end

class PartiallyAnnotated
  include Logit::Instrumentation

  @[Logit::Log]
  def logged_method : Int32
    1
  end

  def unlogged_method : Int32
    2
  end

  Logit.setup_instrumentation(PartiallyAnnotated)
end

# Specs
describe "Logit::Instrumentation" do
  describe "method wrapping" do
    it "preserves method return values" do
      calc = TestCalculator.new
      result = calc.add(5, 3)
      result.should eq(8)
    end

    it "works with multiple arguments" do
      calc = TestCalculator.new
      result = calc.multiply(4, 7)
      result.should eq(28)
    end

    it "works with string arguments" do
      calc = TestCalculator.new
      result = calc.greet("World")
      result.should eq("Hello, World!")
    end

    it "works with methods that have no arguments" do
      calc = TestCalculator.new
      result = calc.no_args
      result.should eq("no args")
    end
  end

  describe "error handling" do
    it "preserves exceptions" do
      calc = TestCalculator.new
      expect_raises(Exception, "Test error") do
        calc.raises_error
      end
    end
  end

  describe "trace propagation" do
    it "propagates trace IDs through nested calls" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      calc = TestCalculator.new
      result = calc.nested_call
      result.should eq(8)

      # The outer span should have been created and popped
      Logit::Span.current?.should be_nil
    end
  end

  describe "span lifecycle" do
    it "creates a span for each annotated method call" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      calc = TestCalculator.new
      calc.add(1, 2)

      # After the call, the span should be popped
      Logit::Span.current?.should be_nil
    end

    it "maintains parent-child relationships" do
      # Clear any existing spans
      while Logit::Span.current?
        Logit::Span.pop
      end

      # Create a manual parent span
      parent = Logit::Span.new("parent")
      Logit::Span.push(parent)

      calc = TestCalculator.new
      calc.add(1, 2)

      # The add call should have created a child span
      # and cleaned it up, leaving only the parent
      Logit::Span.current.should eq(parent)

      Logit::Span.pop
    end
  end
end

describe "Logit::Log annotation" do
  it "can be applied to instance methods" do
    obj = AnnotatedClass.new
    obj.test_method.should eq("test")
  end

  it "works with multiple annotated methods" do
    obj = MultiAnnotated.new
    obj.method_one.should eq(1)
    obj.method_two.should eq(2)
    obj.method_three.should eq(3)
  end

  it "does not affect non-annotated methods" do
    obj = PartiallyAnnotated.new
    obj.logged_method.should eq(1)
    obj.unlogged_method.should eq(2)
  end
end
