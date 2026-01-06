require "../backend"
require "../utils/safe_output"
require "./buffered"

module Logit
  # Backend that writes log events to a file.
  #
  # Uses the `Formatter::JSON` formatter by default, which produces structured
  # JSON output suitable for log aggregation and analysis systems.
  #
  # ## Basic Usage
  #
  # ```crystal
  # Logit.configure do |config|
  #   config.file("logs/app.log", level: Logit::LogLevel::Debug)
  # end
  # ```
  #
  # ## Security Features
  #
  # - Files are created with mode 0o600 (owner read/write only) by default
  # - Symlinks are not followed by default (prevents log injection attacks)
  # - Parent directory must exist (prevents path traversal)
  #
  # ## Custom Configuration
  #
  # ```crystal
  # backend = Logit::Backend::File.new(
  #   path: "logs/audit.log",
  #   name: "audit",
  #   level: Logit::LogLevel::Info,
  #   formatter: Logit::Formatter::Human.new,
  #   mode: 0o644,           # World-readable
  #   follow_symlinks: true  # Allow symlinks
  # )
  # ```
  #
  # ## Output Example (JSON formatter)
  #
  # ```json
  # {"trace_id":"abc...","span_id":"def...","name":"find_user","level":"info",...}
  # ```
  class Backend::File < Logit::Backend
    include BufferedIO

    # Raised when the log file path is invalid.
    class InvalidPathError < Exception; end

    # Raised when the path is a symlink and follow_symlinks is false.
    class SymlinkError < Exception; end

    # Default file permission mode (owner read/write only).
    DEFAULT_FILE_MODE = 0o600

    @path : String
    @file : ::File
    @formatter : Formatter?
    @mode : Int32
    @follow_symlinks : Bool

    # Creates a new file backend.
    #
    # - *path*: Path to the log file (will be created if it doesn't exist)
    # - *name*: Backend name for identification (default: "file")
    # - *level*: Minimum log level (default: Info)
    # - *formatter*: Output formatter (default: JSON)
    # - *mode*: File permission mode for new files (default: 0o600)
    # - *follow_symlinks*: Whether to allow symlink paths (default: false)
    #
    # Raises `InvalidPathError` if the path is invalid or cannot be opened.
    # Raises `SymlinkError` if the path is a symlink and follow_symlinks is false.
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

    # Logs an event to the file.
    def log(event : Event) : Nil
      return unless should_log?(event)

      formatted = @formatter.try(&.format(event)) || event.to_json
      buffered_write(@file, formatted)
    end

    # Flushes the output buffer to disk.
    def flush : Nil
      flush_buffer(@file)
    end

    # Closes the file handle, flushing any remaining buffered data.
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
