require "../src/logit"

# Configure Logit with a console backend at Debug level
Logit.configure do |config|
  config.console(Logit::LogLevel::Debug)
end

# Test class with annotated methods
# No include needed! Just add @[Logit::Log] annotations.
class Calculator
  @[Logit::Log]
  def add(x : Int32, y : Int32) : Int32
    puts "  [inside add] Computing #{x} + #{y}"
    x + y
  end

  @[Logit::Log]
  def causes_error : String
    puts "  [inside causes_error] Raising error..."
    raise "Intentional error for testing"
  end
end

# Run tests
puts "=" * 60
puts "Logit Test Program"
puts "=" * 60
puts ""

calc = Calculator.new

puts "1. Testing basic method (add)..."
result = calc.add(5, 3)
puts "   Result: #{result}"
puts ""

puts "2. Testing error handling..."
begin
  calc.causes_error
rescue ex
  puts "   Caught expected error: #{ex.message}"
end
puts ""

puts "=" * 60
puts "Test program complete!"
puts "=" * 60
