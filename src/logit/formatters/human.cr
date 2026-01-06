require "../formatter"
require "../events/event"
require "json"

module Logit
  # Human-readable formatter with colorized output.
  #
  # Produces output optimized for terminal viewing during development.
  # Includes ANSI color codes for log levels and uses a compact, readable format.
  #
  # ## Output Format
  #
  # ```
  # HH:MM:SS.mmm LEVEL Class#method (duration) → return_value  file.cr:line
  #     args: arg1=value1, arg2=value2
  # ```
  #
  # ## Example Output
  #
  # ```
  # 10:30:45.123 INFO  UserService#find_user (2ms) → User{id: 42}  user_service.cr:15
  #     args: id=42
  # 10:30:45.125 ERROR PaymentService#charge (15ms)  payment_service.cr:42
  #     args: amount=99.99
  #     ✖ PaymentError: Card declined
  # ```
  #
  # ## Color Coding
  #
  # - TRACE: White
  # - DEBUG: Cyan
  # - INFO: Green
  # - WARN: Yellow
  # - ERROR: Red
  # - FATAL: Magenta
  class Formatter::Human < Formatter
    # Formats an event into a human-readable string with ANSI colors.
    def format(event : Event) : String
      String.build do |io|
        # Timestamp - short format (HH:MM:SS.mmm)
        io << event.timestamp.to_utc.to_s("%H:%M:%S.%3N")
        io << " "

        # Level (colorized, right-padded to 5 chars)
        io << level_color(event.level)
        io << " "

        # Trace ID (truncated to 8 chars) - only show if nested
        if event.parent_span_id
          io << "["
          io << event.trace_id[0..7]
          io << "] "
        end

        # Method signature - class#method
        # Strip surrounding quotes if present (workaround for macro issue)
        class_name = event.class_name
        class_name = class_name[1..-2] if class_name.starts_with?("\"") && class_name.ends_with?("\"")
        method_name = event.method_name
        method_name = method_name[1..-2] if method_name.starts_with?("\"") && method_name.ends_with?("\"")
        io << class_name << "#" << method_name

        # Duration (if present)
        if event.duration_ms > 0
          io << " ("
          format_duration(io, event.duration_ms)
          io << ")"
        end

        # Return value on main line (special handling for code.return)
        if return_value = event.attributes.get("code.return")
          io << " "
          io << "\e[90m"
          io << "→ "
          io << "\e[0m"
          format_value(io, return_value)
        end

        # Code location (basename only) - on main line
        io << "  "
        io << "\e[90m"
        io << basename(event.code_file)
        io << ":"
        io << event.code_line
        io << "\e[0m"

        # Arguments on second line (special handling for code.arguments)
        if args_value = event.attributes.get("code.arguments")
          io << "\n    "
          io << "\e[90m" # Dark gray
          io << "args: "
          io << "\e[0m"
          format_arguments(io, args_value)
        end

        # Exception (if any) - multi-line with proper formatting
        if ex = event.exception
          io << "\n"
          io << "\e[31m"
          io << "    ✖ "
          io << ex.type
          io << "\e[0m"
          if ex.message && !ex.message.empty?
            io << ": "
            io << ex.message
          end
        end
      end
    end

    private def level_color(level : LogLevel) : String
      case level
      when LogLevel::Trace then "\e[37mTRACE\e[0m"
      when LogLevel::Debug then "\e[36mDEBUG\e[0m"
      when LogLevel::Info  then "\e[32mINFO \e[0m"
      when LogLevel::Warn  then "\e[33mWARN \e[0m"
      when LogLevel::Error then "\e[31mERROR\e[0m"
      when LogLevel::Fatal then "\e[35mFATAL\e[0m"
      else                      "\e[0m" + level.to_s + "\e[0m"
      end
    end

    private def format_duration(io : IO, ms : Int64) : Nil
      if ms < 1
        io << (ms * 1000).to_i << "μs"
      elsif ms < 1000
        io << ms << "ms"
      else
        seconds = ms / 1000.0
        io << sprintf("%.2fs", seconds)
      end
    end

    private def basename(path : String) : String
      # Strip leading/trailing quotes from path (workaround for macro issue)
      result = path.strip

      # Strip leading quote
      result = result[1..] if result.starts_with?('"')

      # Strip trailing quote
      result = result[..-2] if result.ends_with?('"')

      # Get just the filename
      parts = result.split('/')
      final_result = parts.last? || result

      # Strip any remaining trailing quote (just in case)
      final_result = final_result[..-2] if final_result.ends_with?('"')

      final_result
    end

    private def format_arguments(io : IO, args_json : ::JSON::Any) : Nil
      case raw = args_json.raw
      when Hash
        first = true
        raw.each do |kv|
          io << ", " unless first
          first = false
          # kv[0] is a String key - output it directly
          key = kv[0].as(String)
          # Strip surrounding quotes if present (workaround for macro issue)
          key = key[1..-2] if key.starts_with?("\"") && key.ends_with?("\"")
          io << key << "="
          format_value(io, kv[1])
        end
      else
        io << args_json.to_json
      end
    end

    private def format_value(io : IO, value : ::JSON::Any) : Nil
      case raw = value.raw
      when String
        if raw.size > 50
          io << "\""
          io << raw[0..47]
          io << "...\""
        else
          io << "\""
          io << raw
          io << "\""
        end
      when Nil
        io << "nil"
      when Bool, Number
        io << raw.to_s
      when Hash
        io << "{"
        first = true
        raw.each do |kv|
          io << ", " unless first
          first = false
          key = kv[0].as(String)
          # Strip surrounding quotes if present (workaround for macro issue)
          key = key[1..-2] if key.starts_with?("\"") && key.ends_with?("\"")
          io << key << "="
          format_value(io, kv[1])
        end
        io << "}"
      when Array
        io << "["
        first = true
        raw.each do |item|
          io << ", " unless first
          first = false
          format_value(io, item)
        end
        io << "]"
      else
        io << value.to_json
      end
    end
  end
end
