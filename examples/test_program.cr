require "../src/logit"

# Configure Logit with a console backend at Debug level
Logit.configure do |config|
  config.console(Logit::LogLevel::Debug)
end

# Test class with annotated methods
class Calculator
  include Logit::Instrumentation

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

  # Call this macro AFTER all methods are defined - pass the current type
  Logit.setup_instrumentation(Calculator)
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
