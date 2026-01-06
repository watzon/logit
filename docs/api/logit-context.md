# Context

`class`

*Defined in [src/logit/context.cr:64](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L64)*

Manages contextual data that is automatically included in log events.

Context provides a way to attach additional metadata to log events without
passing it through method arguments. There are two types of context:

1. **Fiber context** - Persists for the lifetime of the fiber. Use this for
   request-scoped data like request IDs, user IDs, or session information.

2. **Method context** - Cleared after each instrumented method completes.
   Use this for temporary data relevant only to the current operation.

## Fiber Context (Request-Scoped)

Fiber context persists across all method calls within the same fiber:

```crystal
# In your request handler
Logit.add_fiber_context(request_id: "abc-123", user_id: "user-456")

# All subsequent log events in this fiber will include these values
process_request(data)  # logged with request_id and user_id
save_to_database(data) # also logged with request_id and user_id

# Clear when the request completes
Logit.clear_fiber_context
```

## Method Context (Operation-Scoped)

Method context is automatically cleared after each instrumented method:

```crystal
class OrderService
  @[Logit::Log]
  def process_order(order_id : Int32) : Bool
    # Add context for just this operation
    Logit.add_context(step: "validation")
    validate_order(order_id)

    Logit.add_context(step: "payment")
    charge_payment(order_id)

    true
  end  # context is cleared here
end
```

## Scoped Context

Use `with_fiber_context` to temporarily set context for a block:

```crystal
Logit::Context.with_fiber_context(transaction_id: "txn-789") do
  # All logs in this block include transaction_id
  process_transaction
end  # transaction_id is automatically removed
```

## Context Priority

When both fiber and method context contain the same key, method context
takes precedence.

## Class Methods

### `.clear_fiber`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L103)*

Clears all fiber-local context.

---

### `.clear_method`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L138)*

Clears all method-local context.

---

### `.current`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L66)*

Returns the merged context (fiber + method, method takes precedence).

---

### `.delete(key : String) : String | Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L176)*

Deletes a method-local context value.

---

### `.get_fiber(key : String) : String | Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L97)*

Gets a fiber-local context value.

---

### `.get_method(key : String) : String | Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L132)*

Gets a method-local context value.

---

### `.set_fiber`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L73)*

Sets fiber-local context values that persist across method calls.

---

### `.set_fiber_hash(hash : Hash(String, String)) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L81)*

Sets fiber-local context from a hash.

---

### `.set_fiber_named_tuple(named_tuple : NamedTuple) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L89)*

Sets fiber-local context from a named tuple.

---

### `.set_method`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L108)*

Sets method-local context values (cleared after method completes).

---

### `.set_method_hash(hash : Hash(String, String)) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L116)*

Sets method-local context from a hash.

---

### `.set_method_named_tuple(named_tuple : NamedTuple) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L124)*

Sets method-local context from a named tuple.

---

### `.with_fiber_context`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/context.cr#L154)*

Executes a block with temporary fiber context.

The provided context values are added for the duration of the block,
then restored to their previous state afterward.

```crystal
Logit::Context.with_fiber_context(request_id: "abc-123") do
  # request_id is available here
  process_request
end
# request_id is no longer set
```

---

