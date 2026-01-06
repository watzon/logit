# Getting Started

This guide will get you up and running with Logit in a few minutes.

## Installation

Add Logit to your `shard.yml`:

```yaml
dependencies:
  logit:
    github: watzon/logit
```

Install dependencies:

```bash
shards install
```

## Basic Setup

Require the library and configure it at application startup:

```crystal
require "logit"

Logit.configure do |config|
  config.console(Logit::LogLevel::Debug)
end
```

That's it! Logit is now ready to use.

## Annotating Methods

Add the `@[Logit::Log]` annotation to any method you want to instrument:

```crystal
class UserService
  @[Logit::Log]
  def find_user(id : Int32) : User?
    User.find(id)
  end

  @[Logit::Log]
  def create_user(name : String, email : String) : User
    User.create(name: name, email: email)
  end
end
```

When these methods are called, Logit automatically logs:

- Method name and class
- All arguments
- Return value
- Execution duration
- Any exceptions

## Output Formats

### Human-Readable (Default)

The console backend uses a human-readable format by default:

```
10:30:45.123 INFO  UserService#find_user (2ms) → User{id: 42}  user_service.cr:5
    args: id=42
```

For nested calls, trace IDs are shown:

```
10:30:45.123 INFO  [abc12345] OrderService#process (15ms) → true  order_service.cr:10
    args: order_id=123
10:30:45.125 INFO  [abc12345] PaymentService#charge (10ms) → true  payment_service.cr:20
    args: amount=99.99
```

### JSON Format

For production and log aggregation, use JSON:

```crystal
Logit.configure do |config|
  config.console(
    level: Logit::LogLevel::Info,
    formatter: Logit::Formatter::JSON.new
  )
end
```

Output:

```json
{
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "timestamp": "2025-01-05T21:30:00.123456Z",
  "duration_ms": 2,
  "name": "find_user",
  "level": "info",
  "code": {
    "file": "user_service.cr",
    "line": 5,
    "function": "find_user",
    "namespace": "UserService"
  },
  "attributes": {
    "code.arguments": {"id": 42},
    "code.return": "User{id: 42}"
  }
}
```

## Annotation Options

Control what gets logged per-method:

```crystal
class AuthService
  # Don't log the password argument
  @[Logit::Log(redact: ["password"])]
  def login(username : String, password : String) : Bool
    # password appears as [REDACTED]
  end

  # Don't log arguments at all
  @[Logit::Log(log_args: false)]
  def validate_token(token : String) : Bool
    # ...
  end

  # Don't log the (large) return value
  @[Logit::Log(log_return: false)]
  def fetch_all_users : Array(User)
    # ...
  end

  # Custom span name
  @[Logit::Log(name: "auth.logout")]
  def logout(user : User) : Nil
    # ...
  end
end
```

## Exception Handling

Exceptions are automatically logged with full context:

```crystal
class Calculator
  @[Logit::Log]
  def divide(a : Int32, b : Int32) : Float64
    raise ArgumentError.new("Division by zero") if b == 0
    a.to_f / b
  end
end

Calculator.new.divide(10, 0)
```

Output:

```
10:30:45.123 ERROR Calculator#divide (1ms)  calculator.cr:3
    args: a=10, b=0
    ✖ ArgumentError: Division by zero
```

The exception is re-raised after logging, so your error handling continues to work normally.

## Next Steps

- [Configuration](configuration.md) - Multiple backends, formatters, and levels
- [Advanced Usage](advanced.md) - Context, redaction, and namespace filtering
- [API Reference](api/index.md) - Complete API documentation
