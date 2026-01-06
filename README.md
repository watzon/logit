# Logit

> Annotation-based logging library for Crystal with OpenTelemetry support

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
  - [Basic Setup](#basic-setup)
  - [Annotation-Based Instrumentation](#annotation-based-instrumentation)
  - [Configuration Options](#configuration-options)
  - [OpenTelemetry Attributes](#opentelemetry-attributes)
- [API](#api)
- [Contributing](#contributing)
- [License](#license)

## Background

Inspired by the principles outlined at [loggingsucks.com](https://loggingsucks.com/), Logit provides a modern approach to logging in Crystal through annotation-based instrumentation. Instead of manually adding logging statements throughout your code, simply annotate methods with `@[Logit::Log]` and Logit automatically generates wrappers that capture:

- Method arguments and return values
- Execution time and duration
- Exceptions with full stack traces
- OpenTelemetry trace context (W3C trace/span IDs)
- Fiber-aware span propagation for concurrent code

The library follows OpenTelemetry semantic conventions, making it compatible with observability platforms that support OTLP or OpenTelemetry exporters.

## Install

Add this to your application's `shard.yml`:

```yaml
dependencies:
  logit:
    github: watzon/logit
```

Then run:

```bash
shards install
```

Require the library in your code:

```crystal
require "logit"
```

## Usage

### Basic Setup

Configure Logit with a console backend:

```crystal
require "logit"

Logit.configure do |config|
  config.console(Logit::LogLevel::Debug)
end
```

### Annotation-Based Instrumentation

Include the `Logit::Instrumentation` module in your class, annotate methods with `@[Logit::Log]`, and call `Logit.setup_instrumentation` **after** all methods are defined:

```crystal
class Calculator
  include Logit::Instrumentation

  @[Logit::Log]
  def add(x : Int32, y : Int32) : Int32
    x + y
  end

  @[Logit::Log]
  def divide(x : Int32, y : Int32) : Float64
    x / y
  end

  # Must be called after all methods are defined
  Logit.setup_instrumentation(Calculator)
end

calc = Calculator.new
calc.add(5, 3)
calc.divide(10, 2)
```

Output (Human formatter):

```
[INFO] 2025-01-05T21:30:00.123Z Calculator.add duration=2ms args={x: 5, y: 3} return=8
[INFO] 2025-01-05T21:30:00.125Z Calculator.divide duration=1ms args={x: 10, y: 2} return=5.0
```

### Configuration Options

#### Multiple Backends

```crystal
Logit.configure do |config|
  config.console(Logit::LogLevel::Debug)
  config.file("/var/log/app.log", LogLevel::Info)
end
```

#### Custom Formatters

```crystal
require "logit/formatters/json"

Logit.configure do |config|
  backend = Logit::Backend::Console.new(
    name: "console",
    level: Logit::LogLevel::Info,
    formatter: Logit::Formatter::JSON.new
  )
  config.add_backend(backend)
end
```

#### Annotation Options

```crystal
class UserService
  include Logit::Instrumentation

  # Don't log arguments, use custom span name
  @[Logit::Log(log_args: false, name: "user.lookup")]
  def find_user(id : Int64) : User?
    # ...
  end

  # Don't log return value (useful for large responses)
  @[Logit::Log(log_return: false)]
  def fetch_all_users : Array(User)
    # ...
  end

  Logit.setup_instrumentation(UserService)
end
```

### OpenTelemetry Attributes

Logit supports OpenTelemetry semantic conventions. Set attributes on spans within instrumented methods:

```crystal
class PaymentService
  include Logit::Instrumentation

  @[Logit::Log]
  def process_payment(user_id : Int64, amount : Int64) : Bool
    # Access current span
    span = Logit::Span.current

    # Set OpenTelemetry attributes
    span.attributes.set("enduser.id", user_id)
    span.attributes.set("payment.amount", amount)
    span.attributes.set("payment.currency", "USD")

    # Your business logic here
    true
  end

  Logit.setup_instrumentation(PaymentService)
end
```

JSON output includes all attributes:

```json
{
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "timestamp": "2025-01-05T21:30:00.123456Z",
  "duration_ms": 45,
  "name": "process_payment",
  "level": "info",
  "status": "ok",
  "code": {
    "file": "src/services/payment_service.cr",
    "line": 42,
    "function": "process_payment",
    "namespace": "PaymentService"
  },
  "attributes": {
    "enduser.id": "12345",
    "payment.amount": 1999,
    "payment.currency": "USD"
  }
}
```

## API

### `Logit.configure`

Configure the logging system with backends and tracers.

```crystal
Logit.configure do |config|
  config.console(Logit::LogLevel::Debug)
  config.file("/path/to/log", LogLevel::Warn)
end
```

### `Logit::LogLevel`

Enum of log levels: `Trace`, `Debug`, `Info`, `Warn`, `Error`, `Fatal`.

### `Logit::Span`

Represents a traced operation with duration and attributes.

```crystal
span = Logit::Span.new("operation.name")
span.attributes.set("key", "value")
span.end_time = Time.utc
```

### `Logit::Tracer`

Routes events to backends. Access the default tracer:

```crystal
Logit::Tracer.default.emit(event)
```

### Backends

- **`Logit::Backend::Console`** - Outputs to STDOUT/STDERR
- **`Logit::Backend::File`** - Outputs to a file

### Formatters

- **`Logit::Formatter::Human`** - Human-readable text format
- **`Logit::Formatter::JSON`** - JSON format (OpenTelemetry-compatible)

### `Event::Attributes`

Thread-safe storage for structured attributes.

```crystal
attributes = Logit::Event::Attributes.new
attributes.set("string", "value")
attributes.set("number", 42)
attributes.set("bool", true)
attributes.set_object("nested", {key: "value", count: 1})
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT License - see LICENSE for details.
