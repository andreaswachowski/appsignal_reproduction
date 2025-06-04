# README

This is a demonstration repo to reproduce https://github.com/appsignal/appsignal-ruby/issues/1418.

## Reproduction

In one terminal:

```
docker-compose up -d # to start Redis
bundle
bundle exec sidekiq
```

In another terminal start `bundle exec rails console` and on the console, execute `HelloWorldJob.perform_later`.

In the terminal running sidekiq, the following log line appears:

> {"severity":"INFO","retry":true,"queue":"default","wrapped":"HelloWorldJob","args":[{"job_class":...

However, this line is not forwarded to appsignal: Instead, `log/appsignal.log` shows

> [2025-06-04T13:40:23 (process) #35716][WARN] Logger message was ignored, because it was not a String:
> {"retry" => true, "queue" => "default", "wrapped" => "HelloWorldJob", "args" => [{"job_class" => "HelloWorldJob", ...

## Analysis

When the job starts, `Sidekiq::LogStashJobLogger#call` calls
[Sidekiq::Logging::Shared.log_job](https://github.com/iMacTia/sidekiq-logstash/blob/4ea78598c669364a2577b630633914806eb91e96/lib/sidekiq/logging/shared.rb#L11)
which calls `Sidekiq.logger.info`, passing a simple `Hash` as input, and that is
passed in turn to `Appsignal::Logger.add` (via `Appsignal::Logger.info`).

Crucially, `Appsignal::Logger.add` contains [the following
section](https://github.com/appsignal/appsignal-ruby/blob/84b628568d9c1768a1f21b50e56a0fad1bfc6209/lib/appsignal/logger.rb#L76-L83)

```ruby
unless message.is_a?(String)
  Appsignal.internal_logger.warn(
    "Logger message was ignored, because it was not a String: #{message.inspect}"
  )
  return
end

message = formatter.call(severity, Time.now, group, message) if formatter
```

The check for the message type happens **before** the message is formatted.
This was not always so, the order was reversed with
https://github.com/appsignal/appsignal-ruby/commit/cd2f9fbfe31b39de90bc012ddacaaf9b28fef913

The `Sidekiq::Logging::LogstashFormatter` [produces a
String](https://github.com/iMacTia/sidekiq-logstash/blob/4ea78598c669364a2577b630633914806eb91e96/lib/sidekiq/logging/logstash_formatter.rb#L26), but we never get there.

## Solution

Reverse the order of the two lines above:

```ruby
message = formatter.call(severity, Time.now, group, message) if formatter

unless message.is_a?(String)
  Appsignal.internal_logger.warn(
    "Logger message was ignored, because it was not a String: #{message.inspect}"
  )
  return
end
```
