module Logit
  # Mixin for buffered I/O in backends
  module BufferedIO
    DEFAULT_BUFFER_SIZE = 8192

    @buffer : IO::Memory = IO::Memory.new
    @buffer_size : Int32 = DEFAULT_BUFFER_SIZE
    @buffered : Bool = false
    @buffer_mutex : Mutex = Mutex.new

    # Write data to buffer or directly to IO
    protected def buffered_write(io : IO, data : String) : Nil
      if @buffered
        @buffer_mutex.synchronize do
          @buffer << data << "\n"
          if @buffer.size >= @buffer_size
            io << @buffer.to_s
            io.flush
            @buffer.clear
          end
        end
      else
        io << data << "\n"
        io.flush
      end
    end

    # Flush any buffered data
    protected def flush_buffer(io : IO) : Nil
      if @buffered
        @buffer_mutex.synchronize do
          unless @buffer.pos == 0 && @buffer.size == 0
            @buffer.rewind
            io << @buffer.gets_to_end
            io.flush
            @buffer.clear
          end
        end
      else
        io.flush
      end
    end

    # Set buffer size
    def buffer_size=(size : Int32) : Nil
      @buffer_size = size
    end

    # Set buffered mode
    def buffered=(value : Bool) : Nil
      @buffered = value
    end
  end
end
