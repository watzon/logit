module Logit
  # Manages contextual data that is automatically included in log events.
  #
  # Context provides a way to attach additional metadata to log events without
  # passing it through method arguments. There are two types of context:
  #
  # 1. **Fiber context** - Persists for the lifetime of the fiber. Use this for
  #    request-scoped data like request IDs, user IDs, or session information.
  #
  # 2. **Method context** - Cleared after each instrumented method completes.
  #    Use this for temporary data relevant only to the current operation.
  #
  # ## Fiber Context (Request-Scoped)
  #
  # Fiber context persists across all method calls within the same fiber:
  #
  # ```crystal
  # # In your request handler
  # Logit.add_fiber_context(request_id: "abc-123", user_id: "user-456")
  #
  # # All subsequent log events in this fiber will include these values
  # process_request(data)  # logged with request_id and user_id
  # save_to_database(data) # also logged with request_id and user_id
  #
  # # Clear when the request completes
  # Logit.clear_fiber_context
  # ```
  #
  # ## Method Context (Operation-Scoped)
  #
  # Method context is automatically cleared after each instrumented method:
  #
  # ```crystal
  # class OrderService
  #   @[Logit::Log]
  #   def process_order(order_id : Int32) : Bool
  #     # Add context for just this operation
  #     Logit.add_context(step: "validation")
  #     validate_order(order_id)
  #
  #     Logit.add_context(step: "payment")
  #     charge_payment(order_id)
  #
  #     true
  #   end  # context is cleared here
  # end
  # ```
  #
  # ## Scoped Context
  #
  # Use `with_fiber_context` to temporarily set context for a block:
  #
  # ```crystal
  # Logit::Context.with_fiber_context(transaction_id: "txn-789") do
  #   # All logs in this block include transaction_id
  #   process_transaction
  # end  # transaction_id is automatically removed
  # ```
  #
  # ## Context Priority
  #
  # When both fiber and method context contain the same key, method context
  # takes precedence.
  class Context
    # Returns the merged context (fiber + method, method takes precedence).
    def self.current : Hash(String, String)
      fiber_ctx = Fiber.current.logit_fiber_context
      method_ctx = Fiber.current.logit_method_context
      fiber_ctx.merge(method_ctx)
    end

    # Sets fiber-local context values that persist across method calls.
    def self.set_fiber(**kwargs) : Nil
      fiber_ctx = Fiber.current.logit_fiber_context
      kwargs.each do |key, value|
        fiber_ctx[key.to_s] = value.to_s
      end
    end

    # Sets fiber-local context from a hash.
    def self.set_fiber_hash(hash : Hash(String, String)) : Nil
      fiber_ctx = Fiber.current.logit_fiber_context
      hash.each do |key, value|
        fiber_ctx[key] = value.to_s
      end
    end

    # Sets fiber-local context from a named tuple.
    def self.set_fiber_named_tuple(named_tuple : NamedTuple) : Nil
      fiber_ctx = Fiber.current.logit_fiber_context
      named_tuple.each do |key, value|
        fiber_ctx[key.to_s] = value.to_s
      end
    end

    # Gets a fiber-local context value.
    def self.get_fiber(key : String) : String?
      fiber_ctx = Fiber.current.logit_fiber_context
      fiber_ctx[key]?
    end

    # Clears all fiber-local context.
    def self.clear_fiber : Nil
      Fiber.current.logit_fiber_context.clear
    end

    # Sets method-local context values (cleared after method completes).
    def self.set_method(**kwargs) : Nil
      method_ctx = Fiber.current.logit_method_context
      kwargs.each do |key, value|
        method_ctx[key.to_s] = value.to_s
      end
    end

    # Sets method-local context from a hash.
    def self.set_method_hash(hash : Hash(String, String)) : Nil
      method_ctx = Fiber.current.logit_method_context
      hash.each do |key, value|
        method_ctx[key] = value.to_s
      end
    end

    # Sets method-local context from a named tuple.
    def self.set_method_named_tuple(named_tuple : NamedTuple) : Nil
      method_ctx = Fiber.current.logit_method_context
      named_tuple.each do |key, value|
        method_ctx[key.to_s] = value.to_s
      end
    end

    # Gets a method-local context value.
    def self.get_method(key : String) : String?
      method_ctx = Fiber.current.logit_method_context
      method_ctx[key]?
    end

    # Clears all method-local context.
    def self.clear_method : Nil
      Fiber.current.logit_method_context.clear
    end

    # Executes a block with temporary fiber context.
    #
    # The provided context values are added for the duration of the block,
    # then restored to their previous state afterward.
    #
    # ```crystal
    # Logit::Context.with_fiber_context(request_id: "abc-123") do
    #   # request_id is available here
    #   process_request
    # end
    # # request_id is no longer set
    # ```
    def self.with_fiber_context(**kwargs, &)
      old_context = Fiber.current.logit_fiber_context.dup
      set_fiber(**kwargs)
      yield
    ensure
      Fiber.current.logit_fiber_context.clear
      Fiber.current.logit_fiber_context.merge!(old_context)
    end

    # :nodoc:
    # Legacy alias for `set_method`.
    def self.set(**kwargs) : Nil
      set_method(**kwargs)
    end

    # :nodoc:
    # Legacy alias for `get_method`.
    def self.get(key : String) : String?
      get_method(key)
    end

    # Deletes a method-local context value.
    def self.delete(key : String) : String?
      method_ctx = Fiber.current.logit_method_context
      method_ctx.delete(key)
    end

    # :nodoc:
    # Legacy alias for `clear_method`.
    def self.clear : Nil
      clear_method
    end

    # :nodoc:
    # Legacy alias for `with_fiber_context`.
    def self.with_context(**kwargs, &)
      with_fiber_context(**kwargs) do
        yield
      end
    end
  end

  # Adds method-local context that is cleared after the current method completes.
  #
  # ```crystal
  # @[Logit::Log]
  # def process(item : Item) : Bool
  #   Logit.add_context(item_type: item.type)
  #   # ... context is included in this method's log event
  #   true
  # end  # context cleared here
  # ```
  def self.add_context(**kwargs) : Nil
    Context.set_method(**kwargs)
  end

  # Adds method-local context from a hash.
  def self.add_context(hash : Hash(String, String)) : Nil
    Context.set_method_hash(hash)
  end

  # Adds method-local context from a named tuple.
  def self.add_context(named_tuple : NamedTuple) : Nil
    Context.set_method_named_tuple(named_tuple)
  end

  # Gets a method-local context value.
  def self.get_context(key : String) : String?
    Context.get_method(key)
  end

  # Clears all method-local context.
  def self.clear_context : Nil
    Context.clear_method
  end

  # Adds fiber-local context that persists across method calls in this fiber.
  #
  # Use this for request-scoped data like request IDs or user information.
  #
  # ```crystal
  # # At the start of a request
  # Logit.add_fiber_context(request_id: request.id, user_id: current_user.id)
  #
  # # All logs in this fiber now include request_id and user_id
  # process_request
  # save_data
  #
  # # At the end of the request
  # Logit.clear_fiber_context
  # ```
  def self.add_fiber_context(**kwargs) : Nil
    Context.set_fiber(**kwargs)
  end

  # Adds fiber-local context from a hash.
  def self.add_fiber_context(hash : Hash(String, String)) : Nil
    Context.set_fiber_hash(hash)
  end

  # Adds fiber-local context from a named tuple.
  def self.add_fiber_context(named_tuple : NamedTuple) : Nil
    Context.set_fiber_named_tuple(named_tuple)
  end

  # Gets a fiber-local context value.
  def self.get_fiber_context(key : String) : String?
    Context.get_fiber(key)
  end

  # Clears all fiber-local context.
  def self.clear_fiber_context : Nil
    Context.clear_fiber
  end
end

# Extends Fiber to hold Logit context hashes.
class ::Fiber
  # Fiber-local context that persists across method calls.
  property logit_fiber_context : Hash(String, String) { {} of String => String }

  # Method-local context that is cleared after each instrumented method.
  property logit_method_context : Hash(String, String) { {} of String => String }
end
