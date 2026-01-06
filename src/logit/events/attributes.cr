require "json"

module Logit
  struct Event
    # Type-safe structured attribute storage for log events.
    #
    # Attributes provide a way to attach arbitrary structured data to log
    # events. Values are stored as `JSON::Any` for flexibility while maintaining
    # type safety through the setter methods.
    #
    # ## Setting Attributes
    #
    # Use the type-specific `set` methods for primitive types:
    #
    # ```crystal
    # attrs = Logit::Event::Attributes.new
    #
    # # Primitive types
    # attrs.set("user.name", "alice")
    # attrs.set("user.age", 30_i64)
    # attrs.set("request.latency", 0.042)
    # attrs.set("user.active", true)
    # ```
    #
    # Use `set_object` and `set_array` for complex structures:
    #
    # ```crystal
    # attrs.set_object("user", name: "alice", role: "admin")
    # attrs.set_array("tags", "production", "critical")
    # ```
    #
    # Use `set_any` for any JSON-serializable type:
    #
    # ```crystal
    # attrs.set_any("config", my_config_object)
    # ```
    #
    # ## Getting Attributes
    #
    # ```crystal
    # if value = attrs.get("user.name")
    #   puts value.as_s  # => "alice"
    # end
    # ```
    class Attributes
      # The underlying attribute storage.
      property values : Hash(String, JSON::Any)

      # Creates a new empty Attributes instance.
      def initialize
        @values = {} of String => JSON::Any
      end

      # Sets a string attribute.
      def set(key : String, value : String) : Nil
        @values[key] = JSON::Any.new(value)
      end

      # Sets an integer attribute.
      def set(key : String, value : Int32 | Int64) : Nil
        @values[key] = JSON::Any.new(value.to_i64)
      end

      # Sets a float attribute.
      def set(key : String, value : Float32 | Float64) : Nil
        @values[key] = JSON::Any.new(value.to_f64)
      end

      # Sets a boolean attribute.
      def set(key : String, value : Bool) : Nil
        @values[key] = JSON::Any.new(value)
      end

      # Sets a nil attribute.
      def set(key : String, value : Nil) : Nil
        @values[key] = JSON::Any.new(value)
      end

      # Sets an array attribute.
      def set(key : String, value : Array(JSON::Any)) : Nil
        @values[key] = JSON::Any.new(value)
      end

      # Sets a hash attribute.
      def set(key : String, value : Hash(String, JSON::Any)) : Nil
        @values[key] = JSON::Any.new(value)
      end

      # Sets an attribute from any JSON-serializable value.
      #
      # Use this for custom types that implement `to_json`.
      def set_any(key : String, value : _) : Nil
        @values[key] = to_json_any(value)
      end

      # Sets a nested object attribute from named arguments.
      #
      # ```crystal
      # attrs.set_object("http", method: "POST", status: 200)
      # # Results in: {"http": {"method": "POST", "status": 200}}
      # ```
      def set_object(key : String, **values) : Nil
        hash = {} of String => JSON::Any
        values.each do |k, v|
          hash[k.to_s] = to_json_any(v)
        end
        @values[key] = JSON::Any.new(hash)
      end

      # Sets an array attribute from variadic arguments.
      #
      # ```crystal
      # attrs.set_array("tags", "web", "api", "v2")
      # # Results in: {"tags": ["web", "api", "v2"]}
      # ```
      def set_array(key : String, *values) : Nil
        array = values.to_a.map { |v| to_json_any(v) }
        @values[key] = JSON::Any.new(array)
      end

      # Gets an attribute value, returning nil if not found or if the value is null.
      def get(key : String) : JSON::Any?
        val = @values[key]?
        return nil if val.nil?
        # Return Crystal nil if the JSON value is null
        raw = val.raw
        return nil if raw.nil?
        val
      end

      # Alias for `get`.
      def get?(key : String) : JSON::Any?
        get(key)
      end

      def to_json(json : JSON::Builder) : Nil
        @values.to_json(json)
      end

      def to_json : String
        @values.to_json
      end

      private def to_json_any(value : _) : JSON::Any
        case value
        when JSON::Any        then value
        when String           then JSON::Any.new(value)
        when Int32, Int64     then JSON::Any.new(value.to_i64)
        when Float32, Float64 then JSON::Any.new(value.to_f64)
        when Bool             then JSON::Any.new(value)
        when Nil              then JSON::Any.new(value)
        when Array            then JSON::Any.new(value.map { |v| to_json_any(v) })
        when Hash             then JSON::Any.new(value.transform_values { |v| to_json_any(v) })
        else
          # For custom types, serialize to JSON then parse
          JSON.parse(value.to_json).as(JSON::Any)
        end
      end
    end
  end
end
