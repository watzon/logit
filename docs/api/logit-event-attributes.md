# Attributes

`class`

*Defined in [src/logit/events/attributes.cr:45](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L45)*

Type-safe structured attribute storage for log events.

Attributes provide a way to attach arbitrary structured data to log
events. Values are stored as `JSON::Any` for flexibility while maintaining
type safety through the setter methods.

## Setting Attributes

Use the type-specific `set` methods for primitive types:

```crystal
attrs = Logit::Event::Attributes.new

# Primitive types
attrs.set("user.name", "alice")
attrs.set("user.age", 30_i64)
attrs.set("request.latency", 0.042)
attrs.set("user.active", true)
```

Use `set_object` and `set_array` for complex structures:

```crystal
attrs.set_object("user", name: "alice", role: "admin")
attrs.set_array("tags", "production", "critical")
```

Use `set_any` for any JSON-serializable type:

```crystal
attrs.set_any("config", my_config_object)
```

## Getting Attributes

```crystal
if value = attrs.get("user.name")
  puts value.as_s  # => "alice"
end
```

## Constructors

### `.new`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L50)*

Creates a new empty Attributes instance.

---

## Instance Methods

### `#get(key : String) : JSON::Any | Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L122)*

Gets an attribute value, returning nil if not found or if the value is null.

---

### `#get?(key : String) : JSON::Any | Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L132)*

Alias for `get`.

---

### `#set(key : String, value : String) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L55)*

Sets a string attribute.

---

### `#set(key : String, value : Int32 | Int64) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L60)*

Sets an integer attribute.

---

### `#set(key : String, value : Float32 | Float64) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L65)*

Sets a float attribute.

---

### `#set(key : String, value : Bool) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L70)*

Sets a boolean attribute.

---

### `#set(key : String, value : Nil) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L75)*

Sets a nil attribute.

---

### `#set(key : String, value : Array(JSON::Any)) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L80)*

Sets an array attribute.

---

### `#set(key : String, value : Hash(String, JSON::Any)) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L85)*

Sets a hash attribute.

---

### `#set_any(key : String, value : _) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L92)*

Sets an attribute from any JSON-serializable value.

Use this for custom types that implement `to_json`.

---

### `#set_array(key : String, *values) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L116)*

Sets an array attribute from variadic arguments.

```crystal
attrs.set_array("tags", "web", "api", "v2")
# Results in: {"tags": ["web", "api", "v2"]}
```

---

### `#set_object(key : String, **values) : Nil`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L102)*

Sets a nested object attribute from named arguments.

```crystal
attrs.set_object("http", method: "POST", status: 200)
# Results in: {"http": {"method": "POST", "status": 200}}
```

---

### `#values`

*[View source](https://github.com/watzon/logit/blob/main/src/logit/events/attributes.cr#L47)*

The underlying attribute storage.

---

