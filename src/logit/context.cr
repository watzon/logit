module Logit
  class Context
    @@context = Hash(Fiber, Hash(String, String)).new
    @@method_context = Hash(Fiber, Hash(String, String)).new

    def self.current : Hash(String, String)
      # Merge fiber context and method context, with method context taking precedence
      method_ctx = @@method_context[Fiber.current] ||= {} of String => String
      fiber_ctx = @@context[Fiber.current] ||= {} of String => String
      fiber_ctx.merge(method_ctx)
    end

    # Fiber-local context (persists across method calls in the same fiber)
    def self.set_fiber(**kwargs) : Nil
      fiber_ctx = @@context[Fiber.current] ||= {} of String => String
      kwargs.each do |key, value|
        fiber_ctx[key.to_s] = value.to_s
      end
    end

    def self.set_fiber_hash(hash : Hash(String, String)) : Nil
      fiber_ctx = @@context[Fiber.current] ||= {} of String => String
      hash.each do |key, value|
        fiber_ctx[key] = value.to_s
      end
    end

    def self.set_fiber_named_tuple(named_tuple : NamedTuple) : Nil
      fiber_ctx = @@context[Fiber.current] ||= {} of String => String
      named_tuple.each do |key, value|
        fiber_ctx[key.to_s] = value.to_s
      end
    end

    def self.get_fiber(key : String) : String?
      fiber_ctx = @@context[Fiber.current]?
      fiber_ctx[key]? if fiber_ctx
    end

    def self.clear_fiber : Nil
      @@context.delete(Fiber.current)
    end

    # Method-local context (cleared after each method call)
    def self.set_method(**kwargs) : Nil
      method_ctx = @@method_context[Fiber.current] ||= {} of String => String
      kwargs.each do |key, value|
        method_ctx[key.to_s] = value.to_s
      end
    end

    def self.set_method_hash(hash : Hash(String, String)) : Nil
      method_ctx = @@method_context[Fiber.current] ||= {} of String => String
      hash.each do |key, value|
        method_ctx[key] = value.to_s
      end
    end

    def self.set_method_named_tuple(named_tuple : NamedTuple) : Nil
      method_ctx = @@method_context[Fiber.current] ||= {} of String => String
      named_tuple.each do |key, value|
        method_ctx[key.to_s] = value.to_s
      end
    end

    def self.get_method(key : String) : String?
      method_ctx = @@method_context[Fiber.current]?
      method_ctx[key]? if method_ctx
    end

    def self.clear_method : Nil
      @@method_context.delete(Fiber.current)
    end

    # Temporary context (scoped to a block)
    def self.with_fiber_context(**kwargs, &)
      old_context = (@@context[Fiber.current] ||= {} of String => String).dup
      set_fiber(**kwargs)
      yield
    ensure
      @@context[Fiber.current] = old_context if old_context
    end

    # Legacy methods for backwards compatibility
    def self.set(**kwargs) : Nil
      set_method(**kwargs)
    end

    def self.get(key : String) : String?
      get_method(key)
    end

    def self.delete(key : String) : String?
      method_ctx = @@method_context[Fiber.current]?
      method_ctx.delete(key) if method_ctx
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
