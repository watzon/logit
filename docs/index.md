# Logit

> Annotation-based logging library for Crystal with OpenTelemetry support

## What is Logit?

Inspired by the principles outlined at [loggingsucks.com](https://loggingsucks.com/), Logit provides a modern approach to logging in Crystal through annotation-based instrumentation. Instead of manually adding logging statements throughout your code, simply annotate methods with `@[Logit::Log]` and Logit automatically generates wrappers that capture:

- **Method arguments and return values** - See exactly what went in and came out
- **Execution time and duration** - Performance insights built-in
- **Exceptions with full stack traces** - Debug errors quickly
- **OpenTelemetry trace context** - W3C trace/span IDs for distributed tracing
- **Fiber-aware span propagation** - Safe for concurrent code

## Quick Example

```crystal
require "logit"

# Configure once at startup
Logit.configure do |config|
  config.console(Logit::LogLevel::Debug)
end

# Just annotate your methods
class Calculator
  @[Logit::Log]
  def add(x : Int32, y : Int32) : Int32
    x + y
  end
end

calc = Calculator.new
calc.add(5, 3)
```

Output:

```
10:30:45.123 INFO  Calculator#add (2ms) → 8  calculator.cr:8
    args: x=5, y=3
```

## Features

<div class="grid cards" markdown>

-   :material-pencil-outline:{ .lg .middle } **Annotation-Based**

    ---

    No manual log calls. Annotate methods and Logit handles the rest.

-   :material-chart-timeline:{ .lg .middle } **OpenTelemetry Compatible**

    ---

    W3C trace IDs, semantic attributes, and structured JSON output.

-   :material-filter-variant:{ .lg .middle } **Namespace Filtering**

    ---

    Control log levels per namespace with glob patterns.

-   :material-shield-lock:{ .lg .middle } **Redaction Support**

    ---

    Automatically redact sensitive data like passwords and tokens.

-   :material-console:{ .lg .middle } **Multiple Backends**

    ---

    Console and file backends with pluggable formatters.

-   :material-lightning-bolt:{ .lg .middle } **Fiber-Aware**

    ---

    Safe span context for concurrent Crystal applications.

</div>

## Installation

Add to your `shard.yml`:

```yaml
dependencies:
  logit:
    github: watzon/logit
```

Then run:

```bash
shards install
```

## Next Steps

- [Getting Started](getting-started.md) - Installation and basic usage
- [Configuration](configuration.md) - Backends, formatters, and options
- [Advanced Usage](advanced.md) - Context, redaction, and namespace filtering
- [API Reference](api/index.md) - Complete API documentation
