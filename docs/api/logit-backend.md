# Backend

`class` `abstract`

*Defined in [src/logit/backend.cr:60](https://github.com/watzon/logit/blob/main/src/logit/backend.cr#L60)*

Abstract base class for log output destinations.

Backends receive log events and write them to their destination (console,
file, network, etc.). Each backend has:
- A minimum log level (events below this level are ignored)
- An optional formatter (converts events to strings)
- Namespace bindings (per-namespace level overrides)

## Built-in Backends

- `Backend::Console` - Writes to STDOUT with colorized human-readable output
- `Backend::File` - Writes to a file with JSON output

## Creating a Custom Backend

Subclass `Backend` and implement the `log` method:

```crystal
class MyBackend < Logit::Backend
  def initialize(name = "my_backend", level = Logit::LogLevel::Info)
    super(name, level)
  end

  def log(event : Logit::Event) : Nil
    return unless should_log?(event)

    # Format and output the event
    output = @formatter.try(&.format(event)) || event.to_json
    # ... write output to your destination
  end

  def flush : Nil
    # Flush any buffered data
  end

  def close : Nil
    # Release resources
  end
end
```

## Namespace Bindings

Backends can have different log levels for different namespaces:

```crystal
backend = Logit::Backend::Console.new

# Default level is Info, but Database classes log at Warn
backend.bind("MyApp::Database::*", Logit::LogLevel::Warn)

# Except QueryBuilder, which logs at Debug
backend.bind("MyApp::Database::QueryBuilder", Logit::LogLevel::Debug)
```

## Constructors

### `.new(name : String, level : Logit::LogLevel = LogLevel::Info, formatter : Logit::Formatter | Nil = nil)`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backend.cr#L74)*

Creates a new backend with the given name and level.

---

## Instance Methods

### `#bind(pattern : String, level : LogLevel) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backend.cr#L106)*

Binds a namespace pattern to a specific log level.

Events from classes matching the pattern will use this level instead
of the backend's default level. More specific patterns take precedence.

Pattern syntax:
- `MyApp::*` - matches classes directly in MyApp
- `MyApp::**` - matches classes in MyApp and all nested namespaces
- `MyApp::Database::Query` - matches exactly this class

---

### `#bindings`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backend.cr#L71)*

Namespace-specific log level bindings.

---

### `#close`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backend.cr#L94)*

Closes the backend and releases resources.

Override this if your backend holds resources (file handles, connections).
The default implementation is a no-op.

---

### `#flush`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backend.cr#L87)*

Flushes any buffered data.

Override this if your backend buffers output. The default implementation
is a no-op.

---

### `#formatter`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backend.cr#L68)*

Formatter used to convert events to strings.

---

### `#level`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backend.cr#L65)*

Minimum log level for this backend.

---

### `#log(event : Event) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backend.cr#L81)*

Logs an event to this backend.

Implementations should check `should_log?(event)` before processing.

---

### `#name`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backend.cr#L62)*

Unique name for this backend (used for removal and identification).

---

### `#should_log?(event : Event) : Bool`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backend.cr#L119)*

Checks if this backend should log the given event.

Takes into account both the backend's level and any namespace bindings.

---

### `#should_log_level?(level : LogLevel, namespace : String) : Bool`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backend.cr#L127)*

Checks if this backend would log at the given level for a namespace.

Used for early filtering before creating spans/events.

---

## Nested Types

- [`Console`](logit-backend-console.md) - <p>Backend that writes log events to the console (STDOUT).</p>
- [`File`](logit-backend-file.md) - <p>Backend that writes log events to a file.</p>

