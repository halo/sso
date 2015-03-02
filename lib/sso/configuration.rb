require 'logger'

module SSO
  class Configuration

    def logger
      @logger ||= default_logger
    end
    attr_writer :logger

    def environment
      @environment ||= default_environment
    end
    attr_writer :environment

    private

    def default_logger
      return ::Rails.logger if defined?(::Rails)
      instance = ::Logger.new STDOUT
      instance.level = default_log_level
      instance
    end

    def default_log_level
      case environment
      when 'production' then ::Logger::WARN
      when 'test'       then ::Logger::UNKNOWN
      else                   ::Logger::DEBUG
      end
    end

    def default_environment
      return ::Rails.env if defined?(::Rails)
      return ENV['RACK_ENV'].to_s if ENV['RACK_ENV'].to_s != ''
      'unknown'
    end

  end
end
