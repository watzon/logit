# Log

`annotation`

*Defined in [src/logit/logit.cr:84](https://github.com/watzon/logit/blob/main/src/logit/logit.cr#L84)*

Annotation to mark methods for automatic logging instrumentation.

When a method is annotated with `@[Logit::Log]`, Logit automatically:
- Creates a span when the method is called
- Logs method arguments (unless disabled)
- Logs the return value (unless disabled)
- Logs any exceptions (unless disabled)
- Tracks timing/duration
- Maintains trace context across nested calls

## Basic Usage

```crystal
class UserService
  @[Logit::Log]
  def find_user(id : Int32) : User?
    User.find(id)
  end
end
```

## With Options

```crystal
class AuthService
  @[Logit::Log(log_args: false, redact: ["password"])]
  def authenticate(username : String, password : String) : Bool
    # password won't be logged
  end

  @[Logit::Log(name: "user_logout", level: Logit::LogLevel::Debug)]
  def logout(user : User) : Nil
    # Custom span name and debug level
  end
end
```

