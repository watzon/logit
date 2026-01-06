# JSON

`class`

*Defined in [src/logit/formatters/json.cr:34](https://github.com/watzon/logit/blob/main/src/logit/formatters/json.cr#L34)*

JSON formatter for structured log output.

Produces newline-delimited JSON (NDJSON) output suitable for log
aggregation systems like Elasticsearch, Datadog, or Splunk.

The JSON structure follows OpenTelemetry conventions:

```json
{
  "trace_id": "abc123...",
  "span_id": "def456...",
  "parent_span_id": "ghi789...",
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
  "attributes": {
    "code.arguments": {"id": 42},
    "code.return": "User{id: 42}"
  }
}
```

## Instance Methods

### `#format(event : Event) : String`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/formatters/json.cr#L36)*

Formats an event as a JSON string.

---

