# Formatter

`class` `abstract`

*Defined in [src/logit/formatter.cr:34](https://github.com/watzon/logit/blob/main/src/logit/formatter.cr#L34)*

Abstract base class for log event formatters.

Formatters convert log events into string output. Each backend uses a
formatter to determine how events are displayed or written.

## Built-in Formatters

- `Formatter::Human` - Colorized, human-readable output for terminals
- `Formatter::JSON` - Structured JSON output for log aggregation

## Creating a Custom Formatter

Subclass `Formatter` and implement the `format` method:

```crystal
class MyFormatter < Logit::Formatter
  def format(event : Logit::Event) : String
    String.build do |io|
      io << "[" << event.level.to_s.upcase << "] "
      io << event.class_name << "#" << event.method_name
      io << " (" << event.duration_ms << "ms)"
    end
  end
end

# Use the custom formatter
Logit.configure do |config|
  config.console(formatter: MyFormatter.new)
end
```

## Instance Methods

### `#format(event : Event) : String`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/formatter.cr#L39)*

Formats an event into a string representation.

The returned string should be a complete log line including any
necessary newlines.

---

## Nested Types

- [`Human`](logit-formatter-human.md) - <p>Human-readable formatter with colorized output.</p>
- [`JSON`](logit-formatter-json.md) - <p>JSON formatter for structured log output.</p>

