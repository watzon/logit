# Advanced Usage

This guide covers advanced Logit features for production applications.

## Context

Context allows you to attach metadata to log events without passing it through method arguments. There are two types:

### Fiber Context (Request-Scoped)

Persists across all method calls within the same fiber. Use for request IDs, user IDs, etc:

```crystal
class RequestHandler
  def handle(request : HTTP::Request)
    # Set context at request start
    Logit.add_fiber_context(
      request_id: request.id,
      user_id: current_user.id
    )

    # All logs in this fiber include request_id and user_id
    process_request(request)
    save_to_database(request.data)

    # Clear at request end
    Logit.clear_fiber_context
  end
end
```

### Method Context (Operation-Scoped)

Automatically cleared after each instrumented method:

```crystal
class OrderService
  @[Logit::Log]
  def process_order(order_id : Int32) : Bool
    Logit.add_context(step: "validation")
    validate_order(order_id)

    Logit.add_context(step: "payment")
    charge_payment(order_id)

    true
  end  # context cleared automatically
end
```

### Scoped Context

Temporarily set context for a block:

```crystal
Logit::Context.with_fiber_context(transaction_id: "txn-789") do
  # All logs here include transaction_id
  process_transaction
end
# transaction_id automatically removed
```

## Custom Span Attributes

Access the current span inside instrumented methods to add custom attributes:

```crystal
class PaymentService
  @[Logit::Log]
  def process_payment(user_id : Int64, amount : Float64) : Bool
    if span = Logit::Span.current?
      # Add custom attributes
      span.attributes.set("payment.amount", amount)
      span.attributes.set("payment.currency", "USD")
      span.attributes.set("user.tier", "premium")
    end

    # Your business logic
    true
  end
end
```

### OpenTelemetry Semantic Conventions

Use standard attribute names for interoperability:

```crystal
if span = Logit::Span.current?
  # HTTP attributes
  span.attributes.set("http.method", "POST")
  span.attributes.set("http.route", "/api/orders")
  span.attributes.set("http.status_code", 200_i64)

  # Database attributes
  span.attributes.set("db.system", "postgresql")
  span.attributes.set("db.statement", "SELECT * FROM users")

  # User attributes
  span.attributes.set("enduser.id", "user-123")
  span.attributes.set("enduser.role", "admin")
end
```

## Trace Context

Logit automatically maintains trace context across nested method calls:

```crystal
class OrderService
  @[Logit::Log]
  def process(order_id : Int32) : Bool
    validate(order_id)    # Same trace_id, child span
    charge(order_id)      # Same trace_id, child span
    ship(order_id)        # Same trace_id, child span
    true
  end

  @[Logit::Log]
  def validate(order_id : Int32) : Bool
    # Parent span is process()
    true
  end

  # ... etc
end
```

All spans share the same `trace_id` and form a parent-child hierarchy via `parent_span_id`.

## Early Filtering

For expensive operations, check if logging is enabled before computing:

```crystal
if Logit::Tracer.should_emit?(Logit::LogLevel::Debug)
  # Only compute if debug logging is enabled
  debug_info = expensive_debug_computation
  span.attributes.set("debug.info", debug_info)
end

# With namespace consideration
if Logit::Tracer.should_emit?(Logit::LogLevel::Debug, "MyApp::Metrics")
  # Only if Debug is enabled for MyApp::Metrics namespace
end
```

## Custom Backends

Create backends for custom destinations (databases, network services, etc.):

```crystal
class SlackBackend < Logit::Backend
  def initialize(@webhook_url : String, name = "slack", level = Logit::LogLevel::Error)
    super(name, level)
  end

  def log(event : Logit::Event) : Nil
    return unless should_log?(event)

    # Only send errors to Slack
    message = "#{event.level.to_s.upcase}: #{event.class_name}##{event.method_name}"
    if ex = event.exception
      message += " - #{ex.type}: #{ex.message}"
    end

    HTTP::Client.post(@webhook_url, body: {text: message}.to_json)
  end

  def flush : Nil
    # No buffering
  end

  def close : Nil
    # No resources to release
  end
end

# Use it
Logit.configure do |config|
  config.console
  config.add_backend(SlackBackend.new(ENV["SLACK_WEBHOOK"]))
end
```

## Custom Formatters

Create formatters for custom output formats:

```crystal
class SyslogFormatter < Logit::Formatter
  def format(event : Logit::Event) : String
    severity = case event.level
               when .error?, .fatal? then "ERR"
               when .warn?           then "WARNING"
               when .info?           then "INFO"
               else                       "DEBUG"
               end

    "<#{severity}> #{event.timestamp} #{event.class_name}##{event.method_name}: " \
    "duration=#{event.duration_ms}ms"
  end
end
```

## Tracer Management

For advanced use cases, manage tracers directly:

```crystal
# Get the default tracer
tracer = Logit::Tracer.default

# Add/remove backends at runtime
tracer.add_backend(my_backend)
tracer.remove_backend("backend_name")

# Flush all backends
tracer.flush

# Close all backends (on shutdown)
tracer.close
```

### Multiple Tracers

For multi-tenant or specialized logging:

```crystal
Logit.configure do |config|
  # Default tracer
  config.console

  # Audit tracer
  audit_tracer = Logit::Tracer.new("audit")
  audit_tracer.add_backend(Logit::Backend::File.new("logs/audit.log"))
  config.add_tracer("audit", audit_tracer)
end
```

## Performance Tips

### Buffering

Enable buffering for high-throughput applications:

```crystal
Logit.configure do |config|
  # Console: immediate output (default)
  config.console(buffered: false)

  # File: buffered for performance (default)
  config.file("logs/app.log", buffered: true)
end
```

Call `tracer.flush` periodically or before shutdown to ensure all logs are written.

### Selective Instrumentation

Don't instrument hot paths unnecessarily:

```crystal
class HotPath
  # DON'T instrument tight loops
  def process_item(item)
    # Called millions of times
  end

  # DO instrument the batch operation
  @[Logit::Log]
  def process_batch(items : Array(Item)) : Int32
    items.each { |i| process_item(i) }
    items.size
  end
end
```

### Disable Arguments/Returns for Large Data

```crystal
@[Logit::Log(log_args: false, log_return: false)]
def process_large_payload(data : Bytes) : Bytes
  # Avoid serializing large data
end
```

## Error Isolation

Backend failures don't crash your application:

- Errors are written to STDERR
- Other backends continue to receive events
- Exceptions in backends don't propagate

```crystal
# If SlackBackend fails, console still works
Logit.configure do |config|
  config.console
  config.add_backend(SlackBackend.new(webhook_url))
end
```
