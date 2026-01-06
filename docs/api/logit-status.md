# Status

`enum`

*Defined in [src/logit/events/event.cr:242](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L242)*

Status of an event/span, following OpenTelemetry conventions.

## Constants

### `Ok`

```crystal
Ok = 0
```

The operation completed successfully.

### `Error`

```crystal
Error = 1
```

The operation encountered an error.

## Instance Methods

### `#error?`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L247)*

Returns `true` if this enum value equals `Error`

---

### `#ok?`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L244)*

Returns `true` if this enum value equals `Ok`

---

### `#to_s(io : IO) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L249)*

Appends a `String` representation of this enum member to the given *io*.

See also: `to_s`.

---

### `#to_s`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L253)*

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

