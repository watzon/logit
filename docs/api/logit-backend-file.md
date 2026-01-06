# File

`class`

*Defined in [src/logit/backends/file.cr:43](https://github.com/watzon/logit/blob/main/src/logit/backends/file.cr#L43)*

Backend that writes log events to a file.

Uses the `Formatter::JSON` formatter by default, which produces structured
JSON output suitable for log aggregation and analysis systems.

## Basic Usage

```crystal
Logit.configure do |config|
  config.file("logs/app.log", level: Logit::LogLevel::Debug)
end
```

## Security Features

- Files are created with mode 0o600 (owner read/write only) by default
- Symlinks are not followed by default (prevents log injection attacks)
- Parent directory must exist (prevents path traversal)

## Custom Configuration

```crystal
backend = Logit::Backend::File.new(
  path: "logs/audit.log",
  name: "audit",
  level: Logit::LogLevel::Info,
  formatter: Logit::Formatter::Human.new,
  mode: 0o644,           # World-readable
  follow_symlinks: true  # Allow symlinks
)
```

## Output Example (JSON formatter)

```json
{"trace_id":"abc...","span_id":"def...","name":"find_user","level":"info",...}
```

## Constants

### `DEFAULT_FILE_MODE`

```crystal
DEFAULT_FILE_MODE = 384
```

Default file permission mode (owner read/write only).

## Constructors

### `.new(path : String, name = "file", level = LogLevel::Info, formatter : Formatter | Nil = Formatter::JSON.new, mode : Int32 = DEFAULT_FILE_MODE, follow_symlinks : Bool = false)`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backends/file.cr#L72)*

Creates a new file backend.

- *path*: Path to the log file (will be created if it doesn't exist)
- *name*: Backend name for identification (default: "file")
- *level*: Minimum log level (default: Info)
- *formatter*: Output formatter (default: JSON)
- *mode*: File permission mode for new files (default: 0o600)
- *follow_symlinks*: Whether to allow symlink paths (default: false)

Raises `InvalidPathError` if the path is invalid or cannot be opened.
Raises `SymlinkError` if the path is a symlink and follow_symlinks is false.

---

## Instance Methods

### `#close`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backends/file.cr#L98)*

Closes the file handle, flushing any remaining buffered data.

---

### `#flush`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backends/file.cr#L93)*

Flushes the output buffer to disk.

---

### `#log(event : Event) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/backends/file.cr#L85)*

Logs an event to the file.

---

## Nested Types

- [`InvalidPathError`](logit-backend-file-invalidpatherror.md) - <p>Raised when the log file path is invalid.</p>
- [`SymlinkError`](logit-backend-file-symlinkerror.md) - <p>Raised when the path is a symlink and follow_symlinks is false.</p>

