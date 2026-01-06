module Logit
  class Context
    def self.current : Hash(String, String)
      # Merge fiber context and method context, with method context taking precedence
      fiber_ctx = Fiber.current.logit_fiber_context
      method_ctx = Fiber.current.logit_method_context
      fiber_ctx.merge(method_ctx)
    end

    # Fiber-local context (persists across method calls in the same fiber)
    def self.set_fiber(**kwargs) : Nil
      fiber_ctx = Fiber.current.logit_fiber_context
      kwargs.each do |key, value|
        fiber_ctx[key.to_s] = value.to_s
      end
    end

    def self.set_fiber_hash(hash : Hash(String, String)) : Nil
      fiber_ctx = Fiber.current.logit_fiber_context
      hash.each do |key, value|
        fiber_ctx[key] = value.to_s
      end
    end

    def self.set_fiber_named_tuple(named_tuple : NamedTuple) : Nil
      fiber_ctx = Fiber.current.logit_fiber_context
      named_tuple.each do |key, value|
        fiber_ctx[key.to_s] = value.to_s
      end
    end

    def self.get_fiber(key : String) : String?
      fiber_ctx = Fiber.current.logit_fiber_context
      fiber_ctx[key]?
    end

    def self.clear_fiber : Nil
      Fiber.current.logit_fiber_context.clear
    end

    # Method-local context (cleared after each method call)
    def self.set_method(**kwargs) : Nil
      method_ctx = Fiber.current.logit_method_context
      kwargs.each do |key, value|
        method_ctx[key.to_s] = value.to_s
      end
    end

    def self.set_method_hash(hash : Hash(String, String)) : Nil
      method_ctx = Fiber.current.logit_method_context
      hash.each do |key, value|
        method_ctx[key] = value.to_s
      end
    end

    def self.set_method_named_tuple(named_tuple : NamedTuple) : Nil
      method_ctx = Fiber.current.logit_method_context
      named_tuple.each do |key, value|
        method_ctx[key.to_s] = value.to_s
      end
    end

    def self.get_method(key : String) : String?
      method_ctx = Fiber.current.logit_method_context
      method_ctx[key]?
    end

    def self.clear_method : Nil
      Fiber.current.logit_method_context.clear
    end

    # Temporary context (scoped to a block)
    def self.with_fiber_context(**kwargs, &)
      old_context = Fiber.current.logit_fiber_context.dup
      set_fiber(**kwargs)
      yield
    ensure
      Fiber.current.logit_fiber_context.clear
      Fiber.current.logit_fiber_context.merge!(old_context)
    end

    # Legacy methods for backwards compatibility
    def self.set(**kwargs) : Nil
      set_method(**kwargs)
    end

    def self.get(key : String) : String?
      get_method(key)
    end

    def self.delete(key : String) : String?
      method_ctx = Fiber.current.logit_method_context
      method_ctx.delete(key)
    end

    def self.clear : Nil
      clear_method
    end

    def self.with_context(**kwargs, &)
      with_fiber_context(**kwargs) do
        yield
      end
    end
  end

  # Method-local context (cleared after each method call)
  def self.add_context(**kwargs) : Nil
    Context.set_method(**kwargs)
  end

  def self.add_context(hash : Hash(String, String)) : Nil
    Context.set_method_hash(hash)
  end

  def self.add_context(named_tuple : NamedTuple) : Nil
    Context.set_method_named_tuple(named_tuple)
  end

  def self.get_context(key : String) : String?
    Context.get_method(key)
  end

  def self.clear_context : Nil
    Context.clear_method
  end

  # Fiber-local context (persists across method calls)
  def self.add_fiber_context(**kwargs) : Nil
    Context.set_fiber(**kwargs)
  end

  def self.add_fiber_context(hash : Hash(String, String)) : Nil
    Context.set_fiber_hash(hash)
  end

  def self.add_fiber_context(named_tuple : NamedTuple) : Nil
    Context.set_fiber_named_tuple(named_tuple)
  end

  def self.get_fiber_context(key : String) : String?
    Context.get_fiber(key)
  end

  def self.clear_fiber_context : Nil
    Context.clear_fiber
  end
end

# Extend Fiber to hold context hashes
class ::Fiber
  property logit_fiber_context : Hash(String, String) { {} of String => String }
  property logit_method_context : Hash(String, String) { {} of String => String }
end
