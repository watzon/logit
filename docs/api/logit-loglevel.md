# LogLevel

`enum`

*Defined in [src/logit/log_level.cr:36](https://github.com/watzon/logit/blob/main/src/logit/log_level.cr#L36)*

Log severity levels, ordered from least to most severe.

Events are only logged if their level is greater than or equal to the
backend's configured minimum level. For example, if a backend is set
to `Info`, only `Info`, `Warn`, `Error`, and `Fatal` events are logged.

## Level Descriptions

- `Trace` - Very detailed debugging information, typically only useful
  when diagnosing specific issues
- `Debug` - Detailed information useful during development
- `Info` - General operational information (default level)
- `Warn` - Warning conditions that don't prevent operation but may
  indicate problems
- `Error` - Error conditions that prevented an operation from completing
- `Fatal` - Severe errors that may cause the application to terminate

## Comparison

Log levels can be compared using standard comparison operators:

```crystal
Logit::LogLevel::Info > Logit::LogLevel::Debug  # => true
Logit::LogLevel::Warn >= Logit::LogLevel::Info  # => true
```

## Parsing

Log levels can be parsed from strings (case-insensitive):

```crystal
level = Logit::LogLevel.parse("debug")  # => LogLevel::Debug
level = Logit::LogLevel.parse("INFO")   # => LogLevel::Info
```

## Constants

### `Trace`

```crystal
Trace = 0
```

Very detailed debugging information.

### `Debug`

```crystal
Debug = 1
```

Detailed information useful during development.

### `Info`

```crystal
Info = 2
```

General operational information (default level).

### `Warn`

```crystal
Warn = 3
```

Warning conditions that may indicate problems.

### `Error`

```crystal
Error = 4
```

Error conditions that prevented an operation.

### `Fatal`

```crystal
Fatal = 5
```

Severe errors that may terminate the application.

## Constructors

### `.parse(str : String) : LogLevel`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/log_level.cr#L100)*

Parses a log level from a string (case-insensitive).

Raises `ArgumentError` if the string is not a valid level name.

---

## Instance Methods

### `#<(other : LogLevel) : Bool`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/log_level.cr#L89)*

Compares this object to *other* based on the receiver’s `<=>` method,
returning `true` if it returns a negative number.

---

### `#>(other : LogLevel) : Bool`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/log_level.cr#L93)*

Compares this object to *other* based on the receiver’s `<=>` method,
returning `true` if it returns a value greater then `0`.

---

### `#debug?`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/log_level.cr#L41)*

Returns `true` if this enum value equals `Debug`

---

### `#error?`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/log_level.cr#L50)*

Returns `true` if this enum value equals `Error`

---

### `#fatal?`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/log_level.cr#L53)*

Returns `true` if this enum value equals `Fatal`

---

### `#info?`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/log_level.cr#L44)*

Returns `true` if this enum value equals `Info`

---

### `#to_s(io : IO) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/log_level.cr#L55)*

Appends a `String` representation of this enum member to the given *io*.

See also: `to_s`.

---

### `#to_s`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/log_level.cr#L68)*

Returns a `String` representation of this enum member.
In the case of regular enums, this is just the name of the member.
In the case of flag enums, it's the names joined by vertical bars, or "None",
if the value is zero.

If an enum's value doesn't match a member's value, the raw value
is returned as a string.

```
Color::Red.to_s                     # => "Red"
IOMode::None.to_s                   # => "None"
(IOMode::Read | IOMode::Write).to_s # => "Read | Write"

Color.new(10).to_s # => "10"
```

---

### `#trace?`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/log_level.cr#L38)*

Returns `true` if this enum value equals `Trace`

---

### `#warn?`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/log_level.cr#L47)*

Returns `true` if this enum value equals `Warn`

---

