# Configuration

Logit is configured using the `Logit.configure` block. This guide covers all configuration options.

## Backends

Backends determine where log events are sent. Logit includes two built-in backends.

### Console Backend

Writes to STDOUT with colorized, human-readable output:

```crystal
Logit.configure do |config|
  config.console(level: Logit::LogLevel::Debug)
end
```

Options:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `level` | `LogLevel` | `Info` | Minimum log level |
| `formatter` | `Formatter` | `Human` | Output formatter |
| `buffered` | `Bool` | `false` | Buffer output (improves performance) |

### File Backend

Writes to a file with JSON output (for log aggregation):

```crystal
Logit.configure do |config|
  config.file("logs/app.log", level: Logit::LogLevel::Info)
end
```

Options:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | `String` | required | Path to log file |
| `level` | `LogLevel` | `Info` | Minimum log level |
| `buffered` | `Bool` | `true` | Buffer output |

Security features:

- Files created with mode `0o600` (owner read/write only)
- Symlinks not followed by default
- Parent directory must exist

### Multiple Backends

Use multiple backends simultaneously:

```crystal
Logit.configure do |config|
  # Human-readable for development
  config.console(level: Logit::LogLevel::Debug)

  # JSON for production log aggregation
  config.file("logs/app.log", level: Logit::LogLevel::Info)
end
```

## Formatters

Formatters control how events are rendered as text.

### Human Formatter (Default for Console)

Colorized, compact format for terminal viewing:

```
10:30:45.123 INFO  UserService#find_user (2ms) → User{id: 42}  user_service.cr:15
    args: id=42
```

Color coding:

- TRACE: White
- DEBUG: Cyan
- INFO: Green
- WARN: Yellow
- ERROR: Red
- FATAL: Magenta

### JSON Formatter (Default for File)

Structured JSON following OpenTelemetry conventions:

```json
{
  "trace_id": "abc123...",
  "span_id": "def456...",
  "timestamp": "2024-01-15T10:30:00.000000Z",
  "duration_ms": 42,
  "name": "find_user",
  "level": "info",
  "status": "ok",
  "code": {
    "file": "user_service.cr",
    "line": 15,
    "function": "find_user",
    "namespace": "UserService"
  },
  "attributes": {...}
}
```

### Custom Formatter

Create your own by subclassing `Formatter`:

```crystal
class MyFormatter < Logit::Formatter
  def format(event : Logit::Event) : String
    "[#{event.level.to_s.upcase}] #{event.class_name}##{event.method_name}"
  end
end

Logit.configure do |config|
  config.console(formatter: MyFormatter.new)
end
```

## Log Levels

Log levels from least to most severe:

| Level | Value | Description |
|-------|-------|-------------|
| `Trace` | 0 | Very detailed debugging |
| `Debug` | 1 | Development debugging |
| `Info` | 2 | General operational info (default) |
| `Warn` | 3 | Warning conditions |
| `Error` | 4 | Error conditions |
| `Fatal` | 5 | Severe/fatal errors |

Events are only logged if their level is >= the backend's configured level.

```crystal
# Parse from string
level = Logit::LogLevel.parse("debug")  # => LogLevel::Debug

# Compare levels
Logit::LogLevel::Warn > Logit::LogLevel::Info  # => true
```

## Namespace Filtering

Control log levels per-namespace using patterns:

```crystal
Logit.configure do |config|
  console = config.console(level: Logit::LogLevel::Info)

  # Reduce noise from database classes
  config.bind("MyApp::Database::*", Logit::LogLevel::Warn, console)

  # But keep debug for query builder
  config.bind("MyApp::Database::QueryBuilder", Logit::LogLevel::Debug, console)
end
```

### Pattern Syntax

| Pattern | Matches |
|---------|---------|
| `MyApp::User` | Exactly `MyApp::User` |
| `MyApp::*` | `MyApp::User`, `MyApp::Order` (direct children) |
| `MyApp::**` | `MyApp::User`, `MyApp::DB::Query` (all descendants) |

More specific patterns take precedence over less specific ones.

### Per-Backend Bindings

Different backends can have different namespace rules:

```crystal
Logit.configure do |config|
  console = config.console(level: Logit::LogLevel::Info)
  file = config.file("logs/debug.log", level: Logit::LogLevel::Debug)

  # Console: only warnings from DB
  config.bind("MyApp::DB::*", Logit::LogLevel::Warn, console)

  # File: full debug from DB
  config.bind("MyApp::DB::*", Logit::LogLevel::Debug, file)
end
```

## Redaction

Prevent sensitive data from appearing in logs.

### Global Patterns

Add patterns that apply to all methods:

```crystal
Logit.configure do |config|
  config.console

  # Enable common patterns (password, token, api_key, etc.)
  config.redact_common_patterns

  # Add custom patterns
  config.redact_patterns(/ssn/i, /credit_card/i)
end
```

### Per-Method Redaction

Redact specific arguments:

```crystal
@[Logit::Log(redact: ["password", "pin"])]
def authenticate(username : String, password : String, pin : String) : Bool
  # password and pin appear as [REDACTED]
end
```

## Complete Example

```crystal
require "logit"

Logit.configure do |config|
  # Console for development
  console = config.console(
    level: Logit::LogLevel::Debug,
    formatter: Logit::Formatter::Human.new
  )

  # JSON file for production
  file = config.file(
    "logs/app.log",
    level: Logit::LogLevel::Info
  )

  # Namespace filtering
  config.bind("MyApp::Database::*", Logit::LogLevel::Warn, console)
  config.bind("MyApp::HTTP::*", Logit::LogLevel::Debug, file)

  # Redaction
  config.redact_common_patterns
  config.redact_patterns(/ssn/i)
end
```

## Next Steps

- [Advanced Usage](advanced.md) - Context and custom attributes
- [API Reference](api/index.md) - Complete API documentation
