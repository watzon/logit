# Span

`class`

*Defined in [src/logit/tracing/span.cr:67](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L67)*

Represents a traced operation with timing, attributes, and trace context.

Spans are the core building block of Logit's tracing system. Each instrumented
method call creates a span that tracks:
- Start and end times (for duration calculation)
- Trace and span IDs (for distributed tracing)
- Parent span ID (for call hierarchy)
- Custom attributes (for structured data)
- Exception information (if an error occurred)

Spans are stored in a fiber-local stack, allowing safe concurrent tracing
across multiple fibers without interference.

## Accessing the Current Span

Inside an instrumented method, you can access the current span to add
custom attributes:

```crystal
class OrderService
  @[Logit::Log]
  def process_order(order_id : Int32) : Bool
    # Add custom attributes to the current span
    if span = Logit::Span.current?
      span.attributes.set("order.priority", "high")
      span.attributes.set("order.items_count", 5_i64)
    end

    # ... process the order
    true
  end
end
```

## Trace Context

Nested method calls automatically share the same trace ID and form a
parent-child relationship through span IDs:

```crystal
class PaymentService
  @[Logit::Log]
  def charge(amount : Float64) : Bool
    validate_amount(amount)  # Child span, same trace_id
    process_payment(amount)  # Child span, same trace_id
    true
  end

  @[Logit::Log]
  def validate_amount(amount : Float64) : Bool
    amount > 0
  end

  @[Logit::Log]
  def process_payment(amount : Float64) : Bool
    # ...
    true
  end
end
```

## Constructors

### `.current`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L129)*

Returns the current span for this fiber.

Raises an exception if no span is active. Prefer `current?` unless you're
certain a span exists.

---

### `.new(name : String, span_id : String = Utils::IDGenerator.span_id, parent_span_id : Nil | String = nil)`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L97)*

Creates a new span with the given name.

Automatically inherits the trace ID from the current span (if any),
or generates a new trace ID for root spans. The parent span ID is
set to the current span's ID.

---

## Class Methods

### `.current?`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L120)*

Returns the current span for this fiber, or nil if none is active.

Use this to safely access the current span without raising an exception.

```crystal
if span = Logit::Span.current?
  span.attributes.set("custom.field", "value")
end
```

---

### `.pop(fiber_stack : Array(Span)) : Span | Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L159)*

Optimized version that takes the span stack directly to avoid repeated Fiber.current access.
Used internally by the instrumentation macros.

---

### `.pop`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L152)*

Pops the current span from the fiber-local span stack.

This is called automatically by the instrumentation macros. You typically
don't need to call this directly.

---

### `.push(span : Span, fiber_stack : Array(Span)) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L144)*

Optimized version that takes the span stack directly to avoid repeated Fiber.current access.
Used internally by the instrumentation macros.

---

### `.push(span : Span) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L137)*

Pushes a span onto the fiber-local span stack.

This is called automatically by the instrumentation macros. You typically
don't need to call this directly.

---

## Instance Methods

### `#attributes`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L87)*

Structured attributes attached to this span.

---

### `#end_time`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L84)*

When this span ended (set when the span completes).

---

### `#exception`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L90)*

Exception information if an error occurred during this span.

---

### `#name`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L78)*

Name of this span (typically the method name).

---

### `#parent_span_id`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L75)*

Span ID of the parent span, or nil if this is a root span.

---

### `#span_id`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L72)*

Unique identifier for this span (64-bit hex string).

---

### `#start_time`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L81)*

When this span started.

---

### `#to_event(trace_id : String, level : LogLevel, code_file : String, code_line : Int32, method_name : String, class_name : String) : Event`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L167)*

Converts this span to an Event for logging.

Called automatically when a span completes. You typically don't need
to call this directly.

---

### `#trace_id`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/tracing/span.cr#L69)*

W3C trace ID (128-bit hex string) shared across all spans in a trace.

---

