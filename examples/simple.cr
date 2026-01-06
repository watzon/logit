require "../src/logit"

# Configure Logit
Logit.configure do |config|
  config.console(Logit::LogLevel::Info)
end

# No include needed! Just add annotations
class Calculator
  @[Logit::Log]
  def add(x : Int32, y : Int32) : Int32
    x + y
  end

  @[Logit::Log]
  def divide(x : Int32, y : Int32) : Float64
    x / y.to_f
  end
end

puts "Testing automatic instrumentation..."
calc = Calculator.new
puts "add(5, 3) = #{calc.add(5, 3)}"
puts "divide(10, 2) = #{calc.divide(10, 2)}"
puts "Done!"
