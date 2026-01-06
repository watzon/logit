require "../../events/event"

module Logit
  class Backend::OTLP < Backend
    # Batches events and flushes them periodically or when size threshold is reached.
    #
    # The batch processor uses a background fiber for interval-based flushing
    # and provides thread-safe event buffering.
    class BatchProcessor
      @buffer : Array(Event)
      @buffer_mutex : Mutex
      @batch_size : Int32
      @flush_interval : Time::Span
      @running : Atomic(Bool)
      @on_flush : Proc(Array(Event), Nil)
      @stop_channel : Channel(Nil)

      def initialize(@batch_size : Int32, @flush_interval : Time::Span, &@on_flush : Array(Event) -> Nil)
        @buffer = [] of Event
        @buffer_mutex = Mutex.new
        @running = Atomic(Bool).new(false)
        @stop_channel = Channel(Nil).new(1) # Buffered channel for reliable shutdown
      end

      # Starts the background flush fiber.
      #
      # Must be called before adding events.
      def start : Nil
        return if @running.get
        @running.set(true)
        spawn_flush_fiber
      end

      # Adds an event to the buffer.
      #
      # If the buffer reaches the batch size, flushes immediately.
      def add(event : Event) : Nil
        should_flush = false

        @buffer_mutex.synchronize do
          @buffer << event
          should_flush = @buffer.size >= @batch_size
        end

        flush_now if should_flush
      end

      # Forces an immediate flush of buffered events.
      def flush : Nil
        flush_now
      end

      # Stops the batch processor and flushes remaining events.
      def stop : Nil
        return unless @running.swap(false)

        # Signal the flush fiber to stop
        @stop_channel.send(nil) rescue Channel::ClosedError

        # Flush any remaining events
        flush_now
      end

      private def flush_now : Nil
        events_to_flush = @buffer_mutex.synchronize do
          return if @buffer.empty?
          batch = @buffer.dup
          @buffer.clear
          batch
        end

        # Call flush callback outside the lock
        @on_flush.call(events_to_flush) if events_to_flush
      end

      private def spawn_flush_fiber : Nil
        spawn do
          loop do
            break unless @running.get

            # Use select to wait for either:
            # 1. The flush interval to elapse
            # 2. A stop signal on the channel
            select
            when @stop_channel.receive?
              # Received stop signal, exit loop
              break
            when timeout(@flush_interval)
              # Interval elapsed, flush if still running
              flush_now if @running.get
            end
          end

          # Close channel when fiber exits
          @stop_channel.close rescue nil
        end
      end
    end
  end
end
