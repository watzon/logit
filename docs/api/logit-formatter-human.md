# Human

`class`

*Defined in [src/logit/formatters/human.cr:36](https://github.com/watzon/logit/blob/main/src/logit/formatters/human.cr#L36)*

Human-readable formatter with colorized output.

Produces output optimized for terminal viewing during development.
Includes ANSI color codes for log levels and uses a compact, readable format.

## Output Format

```
HH:MM:SS.mmm LEVEL Class#method (duration) → return_value  file.cr:line
    args: arg1=value1, arg2=value2
```

## Example Output

```
10:30:45.123 INFO  UserService#find_user (2ms) → User{id: 42}  user_service.cr:15
    args: id=42
10:30:45.125 ERROR PaymentService#charge (15ms)  payment_service.cr:42
    args: amount=99.99
    ✖ PaymentError: Card declined
```

## Color Coding

- TRACE: White
- DEBUG: Cyan
- INFO: Green
- WARN: Yellow
- ERROR: Red
- FATAL: Magenta

## Instance Methods

### `#format(event : Event) : String`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/formatters/human.cr#L38)*

Formats an event into a human-readable string with ANSI colors.

---

