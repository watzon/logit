# Event

`struct`

*Defined in [src/logit/events/attributes.cr:4](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L4)*

A structured log event with OpenTelemetry-compatible fields.

Events are the core data structure passed to backends for logging. Each
event contains:
- Trace context (trace_id, span_id, parent_span_id)
- Timing information (timestamp, duration)
- Source location (file, line, method, class)
- Structured attributes
- Exception information (if applicable)

Events are created automatically by the instrumentation system. You
typically interact with events through the `Span` API or by implementing
custom formatters/backends.

## OpenTelemetry Semantic Conventions

Events provide helper methods for setting OpenTelemetry semantic attributes:

```crystal
if span = Logit::Span.current?
  # HTTP attributes
  span.attributes.set("http.method", "POST")
  span.attributes.set("http.route", "/api/users")
  span.attributes.set("http.status_code", 200_i64)

  # Database attributes
  span.attributes.set("db.system", "postgresql")
  span.attributes.set("db.statement", "SELECT * FROM users")
end
```

## JSON Serialization

Events serialize to JSON in an OpenTelemetry-compatible format:

```json
{
  "trace_id": "abc123...",
  "span_id": "def456...",
  "timestamp": "2024-01-15T10:30:00.000000Z",
  "duration_ms": 42,
  "name": "find_user",
  "level": "info",
  "code": {
    "file": "user_service.cr",
    "line": 15,
    "function": "find_user",
    "namespace": "UserService"
  },
  "attributes": { ... }
}
```

## Constructors

### `.new(trace_id : String, span_id : String, name : String, level : Logit::LogLevel, code_file : String, code_line : Int32, method_name : String, class_name : String, parent_span_id : Nil | String = nil)`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L102)*

Creates a new event with the given parameters.

---

## Instance Methods

### `#attributes`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L96)*

Structured attributes attached to this event.

---

### `#class_name`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L93)*

Fully-qualified class name containing the instrumented method.

---

### `#code_file`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L84)*

Source file where the instrumented method is defined.

---

### `#code_line`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L87)*

Line number where the instrumented method is defined.

---

### `#duration_ms`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L72)*

Duration of the operation in milliseconds.

---

### `#exception`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L99)*

Exception information if an error occurred.

---

### `#level`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L78)*

Log level of this event.

---

### `#method_name`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L90)*

Name of the instrumented method.

---

### `#name`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L75)*

Name of this event (typically the method name).

---

### `#parent_span_id`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L66)*

Span ID of the parent span, or nil if this is a root span.

---

### `#set_code_function(function : String) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L168)*

Code attributes

---

### `#set_db_system(system : String) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L133)*

Database attributes

---

### `#set_exception_type(type : String) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L159)*

Exception attributes

---

### `#set_http_method(method : String) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L116)*

Sets the HTTP request method (e.g., "GET", "POST").

---

### `#set_service_name(name : String) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L177)*

Service attributes

---

### `#set_user_id(id : String | Int64) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L150)*

User attributes

---

### `#span_id`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L63)*

Unique identifier for the span that generated this event.

---

### `#status`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L81)*

Status of the operation (Ok or Error).

---

### `#timestamp`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L69)*

When this event was created.

---

### `#to_json(json : JSON::Builder) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L186)*

Serialize to JSON

---

### `#trace_id`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L60)*

W3C trace ID (128-bit hex string) shared across all spans in a trace.

---

## Nested Types

- [`Attributes`](logit-event-attributes.md) - <p>Type-safe structured attribute storage for log events.</p>

