# ExceptionInfo

`struct`

*Defined in [src/logit/events/event.cr:268](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L268)*

Structured exception information for log events.

Captures exception details in a format suitable for logging and
analysis. Created automatically when an exception occurs in an
instrumented method.

## Constructors

### `.from_exception(ex : Exception) : self`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L283)*

Creates an ExceptionInfo from a Crystal exception.

---

### `.new(type : String, message : String, stacktrace : Nil | Array(String) = nil)`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L279)*

Creates a new ExceptionInfo with the given details.

---

## Instance Methods

### `#message`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L273)*

The exception message.

---

### `#stacktrace`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L276)*

Stack trace as an array of strings, or nil if not available.

---

### `#type`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/event.cr#L270)*

The exception class name (e.g., "ArgumentError").

---

