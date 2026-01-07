# Using Logit in Library Shards

This guide covers best practices for using Logit in library shards to provide observability without imposing logging on consuming applications.

## Overview

Logit is designed to be library-friendly:

- **NullBackend by default**: When Logit is required but not configured, it uses a `NullBackend` that discards all events silently
- **Application control**: Applications decide if and how to enable library logging
- **Trace context propagation**: Library logs automatically participate in application traces

## Recommended Patterns

### Pattern 1: Manual Logging API

For targeted, specific logging in libraries:

```crystal
# my-lib/src/my-lib.cr
require "logit"

module MyLib
  def self.execute_query(sql : String) : Array(Result)
    # Lazy debug log - only computed if debug enabled
    Logit.debug { "Executing SQL: #{sql}" }
    
    start = Time.monotonic
    results = DB.query(sql)
    duration = (Time.monotonic - start).total_milliseconds
    
    # Log with structured attributes
    Logit.info("Query complete",
      rows: results.size,
      duration_ms: duration.to_i64,
      table: extract_table(sql)
    )
    
    results
  rescue ex : DB::Error
    # Log exceptions with full context
    Logit.exception("Query failed", ex)
    raise ex
  end
end
```

### Pattern 2: Annotation-Based Instrumentation

For methods that benefit from automatic tracing:

```crystal
module MyLib
  class HTTPClient
    @[Logit::Log]
    def get(url : String) : HTTP::Response
      # Add custom attributes to the span
      if span = Logit::Span.current?
        span.attributes.set("http.url", url)
        span.attributes.set("http.method", "GET")
      end
      
      response = HTTP::Client.get(url)
      
      if span = Logit::Span.current?
        span.attributes.set("http.status_code", response.status_code.to_i64)
      end
      
      response
    end
  end
end
```

### Pattern 3: Span Events for Long Operations

For operations with distinct phases:

```crystal
module MyLib
  class DataSync
    @[Logit::Log]
    def sync_all : SyncResult
      span = Logit::Span.current
      
      span.add_event("sync.started", source: "api")
      
      data = fetch_data
      span.add_event("sync.fetched", records: data.size)
      
      validated = validate_data(data)
      span.add_event("sync.validated", valid: validated.size, invalid: data.size - validated.size)
      
      persist_data(validated)
      span.add_event("sync.persisted")
      
      SyncResult.new(total: data.size, synced: validated.size)
    end
  end
end
```

### Pattern 4: Manual Spans for Non-Method Operations

For tracing operations that aren't method calls:

```crystal
module MyLib
  def self.batch_process(items : Array(Item)) : BatchResult
    span = Logit::Span.new("mylib.batch_process")
    span.attributes.set("batch.size", items.size.to_i64)
    Logit::Span.push(span)
    
    begin
      results = items.map { |item| process_item(item) }
      
      span.attributes.set("batch.success", results.count(&.success?).to_i64)
      span.attributes.set("batch.failed", results.count(&.failed?).to_i64)
      
      BatchResult.new(results)
    rescue ex
      span.exception = Logit::ExceptionInfo.from_exception(ex)
      raise ex
    ensure
      span.end_time = Time.utc
      
      event = span.to_event(
        trace_id: span.trace_id,
        level: Logit::LogLevel::Info,
        code_file: __FILE__,
        code_line: __LINE__,
        method_name: "batch_process",
        class_name: "MyLib"
      )
      
      Logit::Tracer.default.emit(event)
      Logit::Span.pop
    end
  end
end
```

## Best Practices

### 1. Never Configure Backends in Libraries

Let applications decide how to log:

```crystal
# BAD - Don't do this in a library
Logit.configure do |config|
  config.console(Logit::LogLevel::Debug)
end

# GOOD - Just use Logit, let apps configure
Logit.debug { "Library operation" }
```

### 2. Use Lazy Evaluation

Avoid computing expensive log messages when logging is disabled:

```crystal
# BAD - Always computes the message
Logit.debug("State: #{expensive_state_dump()}")

# GOOD - Only computes if debug is enabled
Logit.debug { "State: #{expensive_state_dump()}" }
```

### 3. Follow OpenTelemetry Semantic Conventions

Use standard attribute names for common operations:

```crystal
# HTTP
span.attributes.set("http.method", "POST")
span.attributes.set("http.url", url)
span.attributes.set("http.status_code", 200_i64)

# Database
span.attributes.set("db.system", "postgresql")
span.attributes.set("db.statement", sql)
span.attributes.set("db.operation", "SELECT")

# User
span.attributes.set("enduser.id", user_id.to_s)

# Error
span.attributes.set("exception.type", ex.class.to_s)
span.attributes.set("exception.message", ex.message)
```

### 4. Use Appropriate Log Levels

- **Trace**: Very detailed diagnostics (loop iterations, state changes)
- **Debug**: Diagnostic information for developers
- **Info**: Significant events (operations started/completed)
- **Warn**: Potentially problematic situations
- **Error**: Operation failures
- **Fatal**: Application cannot continue

### 5. Don't Log Sensitive Data

Be careful with PII, credentials, and other sensitive information:

```crystal
# BAD
Logit.debug { "User login: #{username}, password: #{password}" }

# GOOD
Logit.debug { "User login attempt", username: username }

# Or use Logit's redaction
@[Logit::Log(redact: ["password"])]
def authenticate(username : String, password : String) : Bool
  # password will be redacted in logs
end
```

## Application Configuration Guide

For application developers consuming libraries with Logit:

### Basic Configuration

```crystal
require "logit"

Logit.configure do |config|
  config.console(Logit::LogLevel::Info)
end
```

### Per-Library Log Levels

```crystal
Logit.configure do |config|
  console = config.console(Logit::LogLevel::Info)
  
  # Enable debug for specific library
  config.bind "MyLib::**", Logit::LogLevel::Debug, console
  
  # Reduce noise from verbose library
  config.bind "NoisyLib::**", Logit::LogLevel::Warn, console
end
```

### Combine with Crystal Log Integration

```crystal
require "logit"
require "logit/integrations/crystal_log_adapter"

# Configure Logit
Logit.configure do |config|
  config.console(Logit::LogLevel::Debug)
  config.otlp("http://localhost:4318/v1/logs")
end

# Install Crystal Log adapter
Logit::Integrations::CrystalLogAdapter.install

# Now both Logit and Log calls flow through Logit
```

### Production Configuration

```crystal
Logit.configure do |config|
  # Console for local development
  if ENV["ENVIRONMENT"]? == "development"
    config.console(Logit::LogLevel::Debug)
  end
  
  # OTLP for production observability
  config.otlp(
    ENV["OTLP_ENDPOINT"],
    resource_attributes: {
      "service.name" => "my-app",
      "service.version" => ENV["VERSION"]? || "unknown",
      "deployment.environment" => ENV["ENVIRONMENT"]? || "development"
    }
  )
  
  # Reduce library noise in production
  config.bind "VerboseLib::**", Logit::LogLevel::Warn, otlp_backend
end
```

## Testing with Logit

### Capture Logs in Tests

```crystal
class TestBackend < Logit::Backend
  property captured : Array(Logit::Event) = [] of Logit::Event
  
  def initialize
    super("test", Logit::LogLevel::Trace)
  end
  
  def log(event : Logit::Event) : Nil
    @captured << event if should_log?(event)
  end
  
  def clear
    @captured.clear
  end
end

describe MyLib do
  test_backend = TestBackend.new
  
  before_each do
    test_backend.clear
    tracer = Logit::Tracer.new("test")
    tracer.add_backend(test_backend)
    Logit::Tracer.default = tracer
  end
  
  it "logs query execution" do
    MyLib.execute_query("SELECT 1")
    
    test_backend.captured.any? { |e|
      e.attributes.get("log.message").to_s.includes?("Query complete")
    }.should be_true
  end
end
```

## Migration from Crystal Log

If your library currently uses Crystal's built-in `Log`, you can migrate gradually:

### Option 1: Keep Using Crystal Log

Applications can install the adapter to capture your logs:

```crystal
# Application code
require "logit/integrations/crystal_log_adapter"
Logit::Integrations::CrystalLogAdapter.install
```

Your library doesn't need to change.

### Option 2: Migrate to Logit API

Replace `Log` calls with `Logit` calls for better OpenTelemetry integration:

```crystal
# Before
Log.info { "Operation complete" }
Log.for("db").debug { "Query: #{sql}" }

# After
Logit.info { "Operation complete" }
Logit.debug { "Query: #{sql}" }
```

Benefits:
- Better trace context integration
- Structured attributes with type safety
- Span events for intermediate logging
- Direct OTLP export support
