# OTLP

`class`

*Defined in [src/logit/backends/otlp.cr](https://github.com/watzon/logit/blob/main/src/logit/backends/otlp.cr)*

Backend that exports logs to an OpenTelemetry collector via OTLP/HTTP.

Events are batched and sent as OTLP JSON payloads. The backend flushes
either when the batch size is reached or the flush interval elapses.

## Basic Usage

```crystal
Logit.configure do |config|
  config.otlp("http://localhost:4318/v1/logs")
end
```

## With Authentication

```crystal
Logit.configure do |config|
  config.otlp(
    "https://otlp.example.com/v1/logs",
    headers: {"Authorization" => "Bearer #{ENV["OTLP_TOKEN"]}"},
    resource_attributes: {
      "service.name" => "my-app",
      "service.version" => "1.0.0",
      "deployment.environment" => "production"
    }
  )
end
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `endpoint` | `String` | required | OTLP HTTP endpoint URL |
| `level` | `LogLevel` | `Info` | Minimum log level |
| `batch_size` | `Int32` | `512` | Maximum events per batch |
| `flush_interval` | `Time::Span` | `5.seconds` | Time between automatic flushes |
| `headers` | `Hash(String, String)` | `{}` | HTTP headers for authentication |
| `timeout` | `Time::Span` | `30.seconds` | HTTP request timeout |
| `resource_attributes` | `Hash(String, String)` | `{}` | Resource attributes (service.name, etc.) |

## OTLP Payload Format

Events are serialized to the OTLP/HTTP JSON format:

```json
{
  "resourceLogs": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "my-app"}}
      ]
    },
    "scopeLogs": [{
      "scope": {"name": "logit", "version": "0.1.0"},
      "logRecords": [{
        "timeUnixNano": "1704067200000000000",
        "severityNumber": 9,
        "severityText": "INFO",
        "body": {"stringValue": "find_user"},
        "traceId": "ABC123...",
        "spanId": "DEF456...",
        "attributes": [...]
      }]
    }]
  }]
}
```

### Severity Mapping

| Logit Level | OTLP SeverityNumber | OTLP SeverityText |
|-------------|---------------------|-------------------|
| `Trace` | 1 | TRACE |
| `Debug` | 5 | DEBUG |
| `Info` | 9 | INFO |
| `Warn` | 13 | WARN |
| `Error` | 17 | ERROR |
| `Fatal` | 21 | FATAL |

### Attributes

The following attributes are included in each log record:

| Attribute | Source |
|-----------|--------|
| `code.function` | Method name |
| `code.namespace` | Class name |
| `code.filepath` | Source file path |
| `code.lineno` | Line number |
| `logit.duration_ms` | Operation duration in milliseconds |
| `logit.status` | Status (ok/error) |
| `exception.type` | Exception class (if error) |
| `exception.message` | Exception message (if error) |
| `exception.stacktrace` | Stack trace (if error) |

User-defined attributes from `Span.attributes` are also included.

## Error Handling

The backend never crashes the application:

- Network errors are logged to STDERR and batches are dropped
- HTTP 429 (rate limit) responses log a warning
- HTTP 5xx responses log an error and reset the connection
- Failed batches are not retried (no persistent queue)

## Constructors

### `.new(config : Config, name = "otlp", level = LogLevel::Info)`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backends/otlp.cr)*

Creates a new OTLP backend with the given configuration.

---

## Instance Methods

### `#log(event : Event) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backends/otlp.cr)*

Logs an event by adding it to the batch buffer.

The event will be sent when the batch size is reached or the flush interval elapses.

---

### `#flush : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backends/otlp.cr)*

Forces an immediate flush of buffered events.

---

### `#close : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backends/otlp.cr)*

Stops the batch processor and closes the HTTP client.

Flushes any remaining buffered events before closing.

---

## Nested Types

- [`Config`](logit-backend-otlp-config.md) - Configuration options for the OTLP backend.
