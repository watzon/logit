# Tracer

`class`

*Defined in [src/logit/tracing/tracer.cr:43](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L43)*

Routes log events to registered backends.

The Tracer is responsible for:
- Managing a collection of backends
- Emitting events to all applicable backends
- Providing error isolation (one backend failure doesn't affect others)
- Thread-safe backend management

Most applications use the default tracer, which is set up automatically
by `Logit.configure`. You typically don't need to interact with the
Tracer directly.

## Default Tracer

The default tracer is used by all instrumented methods:

```crystal
# Get the default tracer
tracer = Logit::Tracer.default

# Check if logging is enabled at a level
if Logit::Tracer.should_emit?(Logit::LogLevel::Debug)
  # ... expensive debug operation
end
```

## Custom Tracers

For advanced use cases, you can create named tracers:

```crystal
Logit.configure do |config|
  tracer = Logit::Tracer.new("audit")
  tracer.add_backend(Logit::Backend::File.new("audit.log"))
  config.add_tracer("audit", tracer)
end
```

## Constructors

### `.default`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L119)*

Returns the default tracer.

If no tracer has been configured via `Logit.configure`, creates a
default tracer with a console backend at Info level.

---

### `.new(name : String)`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L53)*

Creates a new tracer with the given name.

---

## Class Methods

### `.default=(tracer : Tracer)`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L129)*

Sets the default tracer.

Called automatically by `Logit.configure`. You typically don't need
to call this directly.

---

### `.should_emit?(level : LogLevel, namespace : String) : Bool`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L157)*

Checks if any backend will emit at this level for a specific namespace.

Takes namespace bindings into account for more precise early filtering.

---

### `.should_emit?(level : LogLevel) : Bool`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L146)*

Checks if any backend will emit at this level.

Use this for early filtering to avoid expensive operations when
logging is disabled at a particular level.

```crystal
if Logit::Tracer.should_emit?(Logit::LogLevel::Debug)
  # Only compute expensive debug info if it will be logged
  debug_info = compute_expensive_debug_info
end
```

---

## Instance Methods

### `#add_backend(backend : Backend) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L62)*

Adds a backend to this tracer.

Thread-safe. The backend will receive all events emitted to this tracer
that pass its level and namespace filters.

---

### `#backends`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L48)*

The backends registered with this tracer.

---

### `#close`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L107)*

Closes all backends and releases resources.

Call this during application shutdown to ensure log files are properly
closed and all data is flushed.

---

### `#emit(event : Event) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L82)*

Emits an event to all registered backends.

Each backend decides whether to log the event based on its level and
namespace bindings. Backend failures are isolated - if one backend
fails, others still receive the event.

---

### `#flush`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L98)*

Flushes all backends.

Call this to ensure buffered log data is written. Useful before
application shutdown or when you need logs to be immediately visible.

---

### `#name`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L45)*

The name of this tracer.

---

### `#remove_backend(name : String) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/tracer.cr#L71)*

Removes a backend by name.

Thread-safe. The backend will no longer receive events.

---

