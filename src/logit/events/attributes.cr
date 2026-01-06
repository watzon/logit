require "json"

module Logit
  struct Event
    # Type-safe attribute storage using JSON::Any for arbitrary structured data
    class Attributes
      property values : Hash(String, JSON::Any)

      def initialize
        @values = {} of String => JSON::Any
      end

      # Type-safe setters that convert to JSON::Any
      def set(key : String, value : String) : Nil
        @values[key] = JSON::Any.new(value)
      end

      def set(key : String, value : Int32 | Int64) : Nil
        @values[key] = JSON::Any.new(value.to_i64)
      end

      def set(key : String, value : Float32 | Float64) : Nil
        @values[key] = JSON::Any.new(value.to_f64)
      end

      def set(key : String, value : Bool) : Nil
        @values[key] = JSON::Any.new(value)
      end

      def set(key : String, value : Nil) : Nil
        @values[key] = JSON::Any.new(value)
      end

      def set(key : String, value : Array(JSON::Any)) : Nil
        @values[key] = JSON::Any.new(value)
      end

      def set(key : String, value : Hash(String, JSON::Any)) : Nil
        @values[key] = JSON::Any.new(value)
      end

      # Generic setter for any JSON-serializable type
      def set_any(key : String, value : _) : Nil
        # Convert to JSON then parse back to get JSON::Any
        json_str = value.to_json
        @values[key] = JSON.parse(json_str).as(JSON::Any)
      end

      # Convenience setters for complex types
      def set_object(key : String, **values) : Nil
        hash = {} of String => JSON::Any
        values.each do |k, v|
          hash[k.to_s] = to_json_any(v)
        end
        @values[key] = JSON::Any.new(hash)
      end

      def set_array(key : String, *values) : Nil
        array = values.to_a.map { |v| to_json_any(v) }
        @values[key] = JSON::Any.new(array)
      end

      # Getters
      def get(key : String) : JSON::Any?
        val = @values[key]?
        return nil if val.nil?
        # Return Crystal nil if the JSON value is null
        raw = val.raw
        return nil if raw.nil?
        val
      end

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
