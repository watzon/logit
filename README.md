# Logit

> Annotation-based logging library for Crystal with OpenTelemetry support

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
  - [Basic Setup](#basic-setup)
  - [Annotation-Based Instrumentation](#annotation-based-instrumentation)
  - [Manual Logging API](#manual-logging-api)
  - [Crystal Log Integration](#crystal-log-integration)
  - [Span Events](#span-events)
  - [Namespace Filtering](#namespace-filtering)
  - [Configuration Options](#configuration-options)
  - [OpenTelemetry Attributes](#opentelemetry-attributes)
- [Library Integration](#library-integration)
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

Simply annotate methods with `@[Logit::Log]` - no includes or setup calls required:

```crystal
class Calculator
  @[Logit::Log]
  def add(x : Int32, y : Int32) : Int32
    x + y
  end

  @[Logit::Log]
  def divide(x : Int32, y : Int32) : Float64
    x / y
  end
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

### Manual Logging API

For libraries or situations where annotations aren't appropriate, Logit provides a manual logging API similar to Crystal's built-in `Log`:

```crystal
# String-based logging
Logit.info("Processing started")
Logit.debug("User authenticated", user_id: 123)
Logit.warn("Slow query", duration_ms: 450, query: sql)

# Lazy evaluation - block only executed if logging is enabled
Logit.debug { "Expensive debug info: #{expensive_operation()}" }

# Exception logging
begin
  risky_operation
rescue ex
  Logit.exception("Operation failed", ex)
  raise ex
end
```

Manual log calls automatically inherit trace context from any active span:

```crystal
@[Logit::Log]
def process_order(order_id : Int64)
  # This log call inherits trace_id and span_id from the annotation
  Logit.info { "Starting order processing" }
  
  validate_order(order_id)
  
  Logit.info { "Order validation complete" }
end
```

### Crystal Log Integration

Logit can capture all calls to Crystal's built-in `Log` library and route them through its backends, enabling unified export to OpenTelemetry collectors.

```crystal
require "logit"
require "logit/integrations/crystal_log_adapter"

# Configure Logit first
Logit.configure do |config|
  config.console(Logit::LogLevel::Debug)
  config.otlp("http://localhost:4318/v1/logs")
end

# Install the adapter
Logit::Integrations::CrystalLogAdapter.install

# All Log.info/debug/etc calls now flow through Logit
Log.info { "This is captured by Logit and exported to OTLP" }
```

When the adapter is installed, Crystal `Log` calls automatically inherit Logit's trace context:

```crystal
@[Logit::Log]
def process_request
  # This Log call inherits the trace context from the span
  Log.info { "Processing request" }
  
  do_work
  
  Log.info { "Request complete" }
end
```

### Span Events

For long-running operations, you can add intermediate events to a span without creating separate spans:

```crystal
@[Logit::Log]
def process_large_file(path : String) : Result
  span = Logit::Span.current
  
  span.add_event("file.opened", path: path)
  
  data = read_file(path)
  span.add_event("file.read", bytes: data.size)
  
  result = process_data(data)
  span.add_event("file.processed", records: result.size)
  
  result
end
```

Span events appear in the JSON output:

```json
{
  "name": "process_large_file",
  "events": [
    {"name": "file.opened", "timestamp": "...", "attributes": {"path": "/data/file.csv"}},
    {"name": "file.read", "timestamp": "...", "attributes": {"bytes": 1024}},
    {"name": "file.processed", "timestamp": "...", "attributes": {"records": 42}}
  ]
}
```

### Namespace Filtering

Logit supports namespace-based filtering, allowing libraries to use Logit internally while giving applications control over which logs they see. This is similar to Crystal's built-in `Log` library.

```crystal
Logit.configure do |c|
  console = c.console(Logit::LogLevel::Info)

  # Log everything at Info level or above
  c.bind "*", LogLevel::Info, console

  # Enable Debug logging for HTTP library
  c.bind "MyLib::HTTP::*", LogLevel::Debug, console

  # Reduce noise from database library
  c.bind "MyLib::DB::*", LogLevel::Warn, console
end
```

#### Pattern Syntax

- **Exact match**: `"MyLib::HTTP"` matches only `MyLib::HTTP`
- **Single wildcard (`*`)**: Matches a single component
  - `"MyLib::*"` matches `MyLib::HTTP` but not `MyLib::HTTP::Client`
  - `"MyLib::HTTP::*"` matches `MyLib::HTTP::Client` but not `MyLib::HTTP::Client::V2`
- **Multi wildcard (`**`)**: Matches zero or more components
  - `"MyLib::**"` matches `MyLib::HTTP`, `MyLib::HTTP::Client`, etc.
  - `"**"` matches everything (root namespace)

#### Multiple Backends

Different backends can have different namespace bindings:

```crystal
Logit.configure do |c|
  console = c.console(Logit::LogLevel::Info)
  file = c.file("/var/log/app.log", LogLevel::Debug)

  # Console: only show warnings from database
  c.bind "MyLib::DB::*", LogLevel::Warn, console

  # File: log everything including debug from database
  c.bind "MyLib::DB::*", LogLevel::Debug, file
end
```

#### Matching Rules

- **Most specific wins**: When multiple patterns match, the longest (most specific) pattern takes precedence
- **Unmatched namespaces**: Use the backend's default level
- **Per-backend**: Bindings are scoped to each backend independently

### Configuration Options

#### Multiple Backends

```crystal
Logit.configure do |config|
  config.console(Logit::LogLevel::Debug)
  config.file("/var/log/app.log", LogLevel::Info)
end
```

#### OpenTelemetry Export

Send logs directly to an OpenTelemetry collector:

```crystal
Logit.configure do |config|
  config.otlp(
    "http://localhost:4318/v1/logs",
    resource_attributes: {
      "service.name" => "my-app",
      "service.version" => "1.0.0"
    }
  )
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
end
```

### OpenTelemetry Attributes

Logit supports OpenTelemetry semantic conventions. Set attributes on spans within instrumented methods:

```crystal
class PaymentService
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

### `Logit.Config#bind`

Bind a namespace pattern to a log level for a specific backend.

```crystal
config.bind("MyLib::**", LogLevel::Debug, backend)
```

Parameters:
- `pattern` : String - Glob pattern for namespace matching
- `level` : LogLevel - Minimum log level for matching namespaces
- `backend` : Backend - Backend to apply the binding to

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
- **`Logit::Backend::OTLP`** - Exports to OpenTelemetry collectors via OTLP/HTTP
- **`Logit::Backend::Null`** - Discards all events (default backend)

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

### Manual Logging Methods

Direct logging without annotations:

```crystal
Logit.trace("message")      # or Logit.trace { "lazy message" }
Logit.debug("message")      # or Logit.debug { "lazy message" }
Logit.info("message")       # or Logit.info { "lazy message" }
Logit.warn("message")       # or Logit.warn { "lazy message" }
Logit.error("message")      # or Logit.error { "lazy message" }
Logit.fatal("message")      # or Logit.fatal { "lazy message" }
Logit.exception("msg", ex)  # Log exception with stack trace
```

## Library Integration

Logit is designed to be library-friendly. By default, it uses a `NullBackend` that discards all events, so libraries can use Logit without imposing logging on applications.

### In Your Library

```crystal
# my-lib/src/my-lib.cr
require "logit"

module MyLib
  def self.query_database(sql : String) : Array(Result)
    # Use manual logging - will be silent unless app configures Logit
    Logit.debug { "Executing SQL: #{sql}" }
    
    results = DB.query(sql)
    
    Logit.info { "Query returned #{results.size} results" }
    results
  end
end
```

### In Your Application

```crystal
require "logit"

# Configure Logit to enable library logging
Logit.configure do |config|
  config.console(Logit::LogLevel::Info)
  
  # Enable debug logs for specific libraries
  config.bind "MyLib::**", Logit::LogLevel::Debug, console
end

require "my-lib"

# Now library logs will appear
MyLib.query_database("SELECT * FROM users")
```

See [docs/library_integration.md](docs/library_integration.md) for detailed guidance.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT License - see LICENSE for details.
