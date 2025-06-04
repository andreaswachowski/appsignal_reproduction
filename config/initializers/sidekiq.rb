# frozen_string_literal: true

Sidekiq::Logstash.setup

Sidekiq.configure_server do |config|
  config.redis = { url: "redis://localhost:6379/" }

  appsignal_logger = Appsignal::Logger.new('sidekiq', format: Appsignal::Logger::JSON)
  appsignal_logger.formatter = Sidekiq::Logging::LogstashFormatter.new
  appsignal_logger.broadcast_to(config.logger)
  config.logger = appsignal_logger
end
