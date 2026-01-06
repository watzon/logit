# Console

`class`

*Defined in [src/logit/backends/console.cr:37](https://github.com/watzon/logit/blob/main/src/logit/backends/console.cr#L37)*

Backend that writes log events to the console (STDOUT).

Uses the `Formatter::Human` formatter by default, which produces colorized,
human-readable output suitable for development and debugging.

## Basic Usage

```crystal
Logit.configure do |config|
  config.console(level: Logit::LogLevel::Debug)
end
```

## Custom Configuration

```crystal
# Use JSON formatter for console output
Logit.configure do |config|
  config.console(
    level: Logit::LogLevel::Info,
    formatter: Logit::Formatter::JSON.new
  )
end
```

## Output Example (Human formatter)

```
10:30:45.123 INFO  UserService#find_user (2ms) → User{id: 42}  user_service.cr:15
    args: id=42
```

## Constructors

### `.new(name = "console", level = LogLevel::Info, formatter = Formatter::Human.new)`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backends/console.cr#L48)*

Creates a new console backend.

- *name*: Backend name for identification (default: "console")
- *level*: Minimum log level (default: Info)
- *formatter*: Output formatter (default: Human)

---

## Instance Methods

### `#flush`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backends/console.cr#L61)*

Flushes the output buffer.

---

### `#io`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backends/console.cr#L41)*

The IO to write to (defaults to STDOUT).

---

### `#log(event : Event) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backends/console.cr#L53)*

Logs an event to the console.

---

