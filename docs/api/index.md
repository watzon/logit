# API Reference

Complete API documentation for Logit, auto-generated from source code.

## Classes

- [`Attributes`](logit-event-attributes.md) - <p>Type-safe structured attribute storage for log events.</p>
- [`Backend`](logit-backend.md) *(abstract)* - <p>Abstract base class for log output destinations.</p>
- [`Config`](logit-config.md) - <p>Configuration builder for setting up Logit logging infrastructure.</p>
- [`Console`](logit-backend-console.md) - <p>Backend that writes log events to the console (STDOUT).</p>
- [`Context`](logit-context.md) - <p>Manages contextual data that is automatically included in log events.</p>
- [`File`](logit-backend-file.md) - <p>Backend that writes log events to a file.</p>
- [`Formatter`](logit-formatter.md) *(abstract)* - <p>Abstract base class for log event formatters.</p>
- [`OTLP`](logit-backend-otlp.md) - <p>Backend that exports logs to an OpenTelemetry collector via OTLP/HTTP.</p>
- [`Human`](logit-formatter-human.md) - <p>Human-readable formatter with colorized output.</p>
- [`JSON`](logit-formatter-json.md) - <p>JSON formatter for structured log output.</p>
- [`Redaction`](logit-redaction.md) - <p>Manages sensitive data redaction for log output.</p>
- [`Span`](logit-span.md) - <p>Represents a traced operation with timing, attributes, and trace context.</p>
- [`Tracer`](logit-tracer.md) - <p>Routes log events to registered backends.</p>

## Structs

- [`Event`](logit-event.md) - <p>A structured log event with OpenTelemetry-compatible fields.</p>
- [`ExceptionInfo`](logit-exceptioninfo.md) - <p>Structured exception information for log events.</p>
- [`NamespaceBinding`](logit-namespacebinding.md) - <p>Binds a namespace pattern to a log level for filtering.</p>

## Enums

- [`LogLevel`](logit-loglevel.md) - <p>Log severity levels, ordered from least to most severe.</p>
- [`Status`](logit-status.md) - <p>Status of an event/span, following OpenTelemetry conventions.</p>

## Annotations

- [`Log`](logit-log.md) - <p>Annotation to mark methods for automatic logging instrumentation.</p>

