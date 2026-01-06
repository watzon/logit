# Config

`class`

*Defined in [src/logit/config.cr:54](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L54)*

Configuration builder for setting up Logit logging infrastructure.

Use `Logit.configure` to create and apply a configuration. The config
provides a fluent API for adding backends, setting up namespace filtering,
and configuring redaction patterns.

## Basic Configuration

```crystal
Logit.configure do |config|
  config.console(level: Logit::LogLevel::Debug)
end
```

## Multiple Backends

```crystal
Logit.configure do |config|
  # Console for development
  console = config.console(level: Logit::LogLevel::Info)

  # JSON file for production logs
  file = config.file("logs/app.log", level: Logit::LogLevel::Debug)

  # Different levels per namespace
  config.bind("MyApp::Database::*", Logit::LogLevel::Warn, console)
  config.bind("MyApp::Http::*", Logit::LogLevel::Debug, file)
end
```

## Redaction

```crystal
Logit.configure do |config|
  config.console

  # Enable common security patterns (password, token, api_key, etc.)
  config.redact_common_patterns

  # Add custom patterns
  config.redact_patterns(/ssn/i, /credit_card/i)
end
```

## Constructors

### `.configure`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L69)*

Creates a new Config, yields it for configuration, and returns it.
Typically you should use `Logit.configure` instead, which also applies
the configuration.

---

### `.new`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L61)*

---

## Instance Methods

### `#add_backend(backend : Backend) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L132)*

Adds a backend to the default tracer.

Creates the default tracer if it doesn't exist. For most applications,
use `console` or `file` methods instead, which call this internally.

---

### `#add_tracer(name : String, tracer : Tracer) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L124)*

Registers a named tracer.

Most applications only need the default tracer, but you can create
additional named tracers for advanced use cases like multi-tenant logging.

---

### `#bind(pattern : String, level : LogLevel, backend : Backend) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L160)*

Binds a namespace pattern to a log level for a specific backend.

This allows fine-grained control over which namespaces (classes) log at
which levels. More specific patterns take precedence over less specific ones.

Pattern syntax:
- `MyApp::*` - matches any class directly in MyApp
- `MyApp::**` - matches any class in MyApp or any nested namespace
- `MyApp::Http::*` - matches classes in MyApp::Http

```crystal
console = config.console

# Only log warnings and above from database classes
config.bind("MyApp::Database::*", Logit::LogLevel::Warn, console)

# But log everything from the query builder
config.bind("MyApp::Database::QueryBuilder", Logit::LogLevel::Debug, console)
```

---

### `#build`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L191)*

Finalizes the configuration by setting the default tracer.
Called automatically by `Logit.configure`.

---

### `#console(level = LogLevel::Info, formatter = Formatter::Human.new, buffered : Bool = false) : Backend::Console`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L89)*

Adds a console backend that writes to STDOUT.

The console backend uses `Formatter::Human` by default, which produces
colorized, human-readable output suitable for development.

- *level*: Minimum log level (default: Info)
- *formatter*: Output formatter (default: Human)
- *buffered*: Whether to buffer output (default: false for immediate display)

Returns the created backend for further configuration (e.g., namespace bindings).

```crystal
config.console(level: Logit::LogLevel::Debug)
```

---

### `#default_tracer_name`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L59)*

Name of the default tracer used by instrumented methods.

---

### `#file(path : String, level = LogLevel::Info, buffered : Bool = true) : Backend::File`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L113)*

Adds a file backend that writes to the specified path.

The file backend uses `Formatter::JSON` by default, which produces
structured JSON output suitable for log aggregation systems.

- *path*: Path to the log file (will be created if it doesn't exist)
- *level*: Minimum log level (default: Info)
- *buffered*: Whether to buffer output (default: true for performance)

Returns the created backend for further configuration (e.g., namespace bindings).

```crystal
config.file("logs/app.log", level: Logit::LogLevel::Debug)
```

NOTE: The file is opened with mode 0o600 (owner read/write only) by default.
Symlinks are not followed unless explicitly enabled in `Backend::File`.

---

### `#redact_common_patterns`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L185)*

Enables a set of common security-related redaction patterns.

This is a convenience method that adds patterns for commonly sensitive
argument names including: password, secret, token, api_key, auth,
credential, private_key, access_key, and bearer.

```crystal
config.redact_common_patterns
```

---

### `#redact_patterns(*patterns : Regex) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L172)*

Adds global redaction patterns that apply to all instrumented methods.

Any argument name matching one of these regex patterns will have its
value replaced with `[REDACTED]` in the logs.

```crystal
config.redact_patterns(/ssn/i, /credit_card/i, /social_security/i)
```

---

### `#tracers`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/config.cr#L56)*

Registered tracers by name.

---

