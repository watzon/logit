require "../src/logit"

# ============================================================================
# Logit Feature Showcase
# ============================================================================
#
# This program demonstrates all major features of the Logit logging library:
#
#   1. Automatic method instrumentation via @[Logit::Log]
#   2. Argument and return value logging
#   3. Exception tracking with stack context
#   4. Nested method calls with trace propagation
#   5. Custom span names and annotation options
#   6. Sensitive data redaction (annotation + global patterns)
#   7. Multiple backends (Console, File)
#   8. Log level filtering and namespace binding
#   9. Different formatters (Human, JSON)
#  10. Buffered I/O for performance
#  11. Fiber-local context management
#
# ============================================================================

# ----------------------------------------------------------------------------
# Section 1: Basic Configuration
# ----------------------------------------------------------------------------

# Clean up any previous log file
File.delete("examples/demo.log") if File.exists?("examples/demo.log")

Logit.configure do |config|
  # Console backend with human-readable format (unbuffered for immediate output)
  config.console(Logit::LogLevel::Debug, Logit::Formatter::Human.new, buffered: false)

  # File backend with JSON format (buffered for performance)
  file_backend = Logit::Backend::File.new(
    "examples/demo.log",
    level: Logit::LogLevel::Debug,
    formatter: Logit::Formatter::JSON.new
  )
  config.add_backend(file_backend)

  # Enable common redaction patterns (password, token, secret, api_key, etc.)
  config.redact_common_patterns

  # Add custom redaction pattern for credit card numbers
  config.redact_patterns(/credit_card/i, /ssn/i)
end

# ----------------------------------------------------------------------------
# Section 2: Basic Instrumentation
# ----------------------------------------------------------------------------

class Calculator
  # Basic method - logs arguments and return value automatically
  @[Logit::Log]
  def add(x : Int32, y : Int32) : Int32
    x + y
  end

  # Method with custom span name
  @[Logit::Log(name: "calculator.multiply")]
  def multiply(a : Int32, b : Int32) : Int32
    a * b
  end

  # Disable argument logging (useful for methods with large payloads)
  @[Logit::Log(log_args: false)]
  def process_data(data : String) : Int32
    data.size
  end

  # Disable return value logging
  @[Logit::Log(log_return: false)]
  def get_secret_value : String
    "this-would-be-hidden"
  end
end

# ----------------------------------------------------------------------------
# Section 3: Nested Calls & Trace Propagation
# ----------------------------------------------------------------------------

class OrderService
  @[Logit::Log]
  def process_order(order_id : String, amount : Float64) : String
    # Nested call - will share the same trace_id
    validated = validate_order(order_id, amount)
    return "rejected" unless validated

    # Another nested call
    payment_id = charge_payment(amount)

    "confirmed:#{payment_id}"
  end

  @[Logit::Log]
  def validate_order(order_id : String, amount : Float64) : Bool
    amount > 0 && !order_id.empty?
  end

  @[Logit::Log]
  def charge_payment(amount : Float64) : String
    # Simulate payment processing
    "pay_#{Random.new.hex(4)}"
  end
end

# ----------------------------------------------------------------------------
# Section 4: Exception Handling
# ----------------------------------------------------------------------------

class RiskyOperation
  @[Logit::Log]
  def might_fail(should_fail : Bool) : String
    if should_fail
      raise ArgumentError.new("Operation failed as requested")
    end
    "success"
  end

  @[Logit::Log]
  def nested_failure : String
    inner_operation
  end

  @[Logit::Log]
  private def inner_operation : String
    raise RuntimeError.new("Deep nested failure")
  end
end

# ----------------------------------------------------------------------------
# Section 5: Sensitive Data Redaction
# ----------------------------------------------------------------------------

class UserService
  # Annotation-level redaction - specific arguments are redacted
  @[Logit::Log(redact: ["password", "ssn"])]
  def create_user(username : String, password : String, email : String, ssn : String) : String
    "user_#{username}_created"
  end

  # Global pattern redaction - "api_key" matches config.redact_common_patterns
  @[Logit::Log]
  def authenticate(username : String, api_key : String) : Bool
    !username.empty? && !api_key.empty?
  end

  # Credit card matches our custom pattern
  @[Logit::Log]
  def process_payment(user_id : String, credit_card : String, amount : Float64) : String
    "payment_processed"
  end
end

# ----------------------------------------------------------------------------
# Section 6: Context Management
# ----------------------------------------------------------------------------

class RequestHandler
  @[Logit::Log]
  def handle_request(request_id : String) : String
    # Set fiber-local context that persists across method calls
    Logit::Context.set_fiber(request_id: request_id, user_agent: "Mozilla/5.0")

    result = process_request
    Logit::Context.clear_fiber
    result
  end

  @[Logit::Log]
  private def process_request : String
    # Context is available here too
    "processed"
  end
end

# ============================================================================
# Run the Demonstrations
# ============================================================================

def section(title : String)
  puts "\n#{"=" * 70}"
  puts "  #{title}"
  puts "#{"=" * 70}\n"
end

def demo(description : String)
  puts "\n--- #{description} ---"
end

# Start
puts "\n"
puts "  #{"*" * 66}"
puts "  *  LOGIT FEATURE SHOWCASE                                         *"
puts "  *  Demonstrating annotation-based logging with OpenTelemetry      *"
puts "  #{"*" * 66}"

# Basic Instrumentation
section("1. BASIC INSTRUMENTATION")

calc = Calculator.new

demo("Simple method with args and return value")
result = calc.add(5, 3)
puts "    Result: #{result}"

demo("Custom span name (calculator.multiply)")
result = calc.multiply(4, 7)
puts "    Result: #{result}"

demo("Logging disabled for arguments (log_args: false)")
result = calc.process_data("Hello, World! This is some test data.")
puts "    Result: #{result} characters"

demo("Logging disabled for return value (log_return: false)")
result = calc.get_secret_value
puts "    Result: #{result}"

# Nested Calls
section("2. NESTED CALLS & TRACE PROPAGATION")

demo("Order processing with nested service calls")
puts "    Notice how nested calls share the same trace ID (shown in brackets)"
order = OrderService.new
confirmation = order.process_order("ORD-12345", 99.99)
puts "    Confirmation: #{confirmation}"

# Exception Handling
section("3. EXCEPTION HANDLING")

risky = RiskyOperation.new

demo("Successful operation")
result = risky.might_fail(false)
puts "    Result: #{result}"

demo("Failed operation (exception logged with context)")
begin
  risky.might_fail(true)
rescue ex
  puts "    Caught: #{ex.message}"
end

demo("Nested failure (trace shows call stack)")
begin
  risky.nested_failure
rescue ex
  puts "    Caught: #{ex.message}"
end

# Redaction
section("4. SENSITIVE DATA REDACTION")

users = UserService.new

demo("Annotation-level redaction (password, ssn)")
puts "    Notice password and ssn show as [REDACTED]"
users.create_user("johndoe", "super_secret_123", "john@example.com", "123-45-6789")

demo("Global pattern redaction (api_key)")
puts "    api_key matches common patterns and is redacted"
users.authenticate("johndoe", "sk_live_abc123xyz")

demo("Custom pattern redaction (credit_card)")
puts "    credit_card matches our custom pattern"
users.process_payment("user_123", "4111-1111-1111-1111", 49.99)

# Context
section("5. FIBER-LOCAL CONTEXT")

demo("Context persists across method calls in the same fiber")
handler = RequestHandler.new
handler.handle_request("req-#{Random.new.hex(4)}")

# Summary
section("6. OUTPUT FILES")

puts "\nConsole output above uses the Human formatter (colorized, readable)."
puts "\nJSON output was written to: examples/demo.log"
puts "Each line is a structured JSON event with OpenTelemetry fields."

if File.exists?("examples/demo.log")
  puts "\nSample from demo.log (first event):"
  puts "-" * 70
  if first_line = File.read_lines("examples/demo.log").first?
    # Pretty print the JSON
    json = JSON.parse(first_line)
    puts JSON.build(indent: "  ") { |builder| json.to_json(builder) }
  end
end

puts "\n#{"=" * 70}"
puts "  Demo complete! All features demonstrated successfully."
puts "#{"=" * 70}\n"
