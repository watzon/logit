require "../backend"
require "../utils/safe_output"
require "./buffered"

module Logit
  class Backend::File < Logit::Backend
    include BufferedIO
    class InvalidPathError < Exception; end
    class SymlinkError < Exception; end

    DEFAULT_FILE_MODE = 0o600  # Owner read/write only

    @path : String
    @file : ::File
    @formatter : Formatter?
    @mode : Int32
    @follow_symlinks : Bool

    def initialize(@path : String, @name = "file", @level = LogLevel::Info,
                   @formatter : Formatter? = Formatter::JSON.new,
                   mode : Int32 = DEFAULT_FILE_MODE,
                   follow_symlinks : Bool = false)
      super(@name, @level)
      @mode = mode
      @follow_symlinks = follow_symlinks
      @buffered = true  # Default to buffered for file backends
      @path = validate_and_canonicalize_path(@path)
      @file = open_with_permissions(@path)
    end

    def log(event : Event) : Nil
      return unless should_log?(event)

      formatted = @formatter.try(&.format(event)) || event.to_json
      buffered_write(@file, formatted)
    end

    def flush : Nil
      flush_buffer(@file)
    end

    def close : Nil
      flush
      @file.close
    end

    private def validate_and_canonicalize_path(path : String) : String
      # Expand to absolute path
      abs_path = ::File.expand_path(path)

      # Check for symlinks unless we're explicitly following them
      if ::File.symlink?(abs_path) && !@follow_symlinks
        raise SymlinkError.new("Path is a symlink: #{abs_path}. Set follow_symlinks: true to allow.")
      end

      # Validate parent directory exists
      parent_dir = ::File.dirname(abs_path)
      unless ::File.directory?(parent_dir)
        raise InvalidPathError.new("Parent directory does not exist: #{parent_dir}")
      end

      # Canonicalize the path (resolves symlinks if following them)
      if ::File.exists?(abs_path)
        ::File.realpath(abs_path)
      else
        # For non-existent files, canonicalize the parent and append the filename
        canonical_parent = ::File.realpath(parent_dir)
        ::File.join(canonical_parent, ::File.basename(abs_path))
      end
    end

    private def open_with_permissions(path : String) : ::File
      # Check if file exists before opening
      file_exists = ::File.exists?(path)

      begin
        # Open in append mode
        file = ::File.open(path, "a")

        # Set permissions for newly created files
        unless file_exists
          begin
            ::File.chmod(path, @mode)
          rescue ex
            Utils::SafeOutput.safe_stderr_write("Logit::Backend::File: Failed to set permissions on #{path}: #{ex.message}")
          end
        end

        file
      rescue ex
        raise InvalidPathError.new("Failed to open file #{path}: #{ex.message}")
      end
    end
  end
end
