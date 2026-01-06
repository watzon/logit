# NamespaceBinding

`struct`

*Defined in [src/logit/namespace_binding.cr:31](https://github.com/watzon/logit/blob/main/src/logit/namespace_binding.cr#L31)*

Binds a namespace pattern to a log level for filtering.

Namespace bindings allow different log levels for different parts of your
codebase. They are created via `Backend#bind` or `Config#bind`.

## Pattern Syntax

Patterns use Crystal's `::` namespace separator with wildcards:

- `MyApp::*` - Matches classes directly in `MyApp` (e.g., `MyApp::User`)
- `MyApp::**` - Matches classes in `MyApp` and all nested namespaces
- `MyApp::Database::Query` - Matches exactly this class

## Examples

```crystal
Logit.configure do |config|
  console = config.console(level: Logit::LogLevel::Info)

  # Reduce noise from database classes
  config.bind("MyApp::Database::*", Logit::LogLevel::Warn, console)

  # But keep verbose logging for query builder
  config.bind("MyApp::Database::QueryBuilder", Logit::LogLevel::Debug, console)
end
```

## Constructors

### `.new(pattern : String, level : LogLevel)`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/namespace_binding.cr#L39)*

Creates a new binding. Raises if the pattern is invalid.

---

## Instance Methods

### `#level`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/namespace_binding.cr#L36)*

The log level for namespaces matching this pattern.

---

### `#matches?(namespace : String) : Bool`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/namespace_binding.cr#L44)*

Checks if a namespace matches this pattern.

---

### `#pattern`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/namespace_binding.cr#L33)*

The namespace pattern (e.g., "MyApp::Database::*").

---

