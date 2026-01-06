# Redaction

`class`

*Defined in [src/logit/redaction.cr:51](https://github.com/watzon/logit/blob/main/src/logit/redaction.cr#L51)*

Manages sensitive data redaction for log output.

Redaction prevents sensitive information (passwords, tokens, API keys, etc.)
from appearing in log output. It works at two levels:

1. **Global patterns**: Regex patterns that apply to all instrumented methods
2. **Annotation-level**: Specific argument names listed in `@[Logit::Log(redact: [...])]`

## Global Patterns

Add regex patterns that match argument names to be redacted:

```crystal
# During configuration
Logit.configure do |config|
  config.console
  config.redact_patterns(/ssn/i, /credit_card/i)
  config.redact_common_patterns  # password, token, api_key, etc.
end

# Or directly via the Redaction class
Logit::Redaction.add_pattern(/social_security/i)
```

## Annotation-Level Redaction

Specify argument names to redact for a specific method:

```crystal
class AuthService
  @[Logit::Log(redact: ["password", "pin"])]
  def authenticate(username : String, password : String, pin : String) : Bool
    # password and pin values will appear as "[REDACTED]" in logs
  end
end
```

## Common Patterns

`enable_common_patterns` adds patterns for commonly sensitive argument names:
- password, passwd
- secret
- token
- api_key, apikey
- auth
- credential
- private_key, privatekey
- access_key, accesskey
- bearer

## Constants

### `REDACTED_VALUE`

```crystal
REDACTED_VALUE = "[REDACTED]"
```

The replacement value for redacted data.

## Class Methods

### `.add_pattern(pattern : Regex) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/redaction.cr#L66)*

Adds a regex pattern for argument name matching.

Any argument whose name matches this pattern will have its value
replaced with `[REDACTED]` in log output.

```crystal
Logit::Redaction.add_pattern(/credit_card/i)
```

---

### `.add_patterns(*patterns : Regex) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/redaction.cr#L77)*

Adds multiple regex patterns at once.

```crystal
Logit::Redaction.add_patterns(/ssn/i, /dob/i, /address/i)
```

---

### `.clear_patterns`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/redaction.cr#L97)*

Clears all global redaction patterns.

Useful for testing or reconfiguration.

---

### `.enable_common_patterns`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/redaction.cr#L126)*

Enables a set of commonly-needed security patterns.

Adds patterns matching: password, passwd, secret, token, api_key,
auth, credential, private_key, access_key, bearer.

All patterns are case-insensitive.

```crystal
Logit::Redaction.enable_common_patterns
```

---

### `.patterns`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/redaction.cr#L88)*

Returns a copy of the current global patterns.

Thread-safe; returns a duplicate array.

---

### `.should_redact?(arg_name : String) : Bool`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/redaction.cr#L106)*

Checks if an argument name matches any global redaction pattern.

Returns true if the value should be replaced with `[REDACTED]`.

---

### `.should_redact_key?(key : String) : Bool`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/redaction.cr#L112)*

Alias for `should_redact?` for key-based checks.

---

