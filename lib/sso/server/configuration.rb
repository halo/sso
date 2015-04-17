require 'logger'

module SSO
  class Configuration

    # Server

    def human_readable_location_for_ip
      @human_readable_location_for_ip || default_human_readable_location_for_ip
    end
    attr_writer :human_readable_location_for_ip

    def user_state_base
      @user_state_base || fail('You need to configure user_state_base, see SSO::Configuration for more info.')
    end
    attr_writer :user_state_base

    def find_user_for_passport
      @find_user_for_passport || fail('You need to configure find_user_for_passport, see SSO::Configuration for more info.')
    end
    attr_writer :find_user_for_passport

    def user_state_key
      @user_state_key || fail('You need to configure a secret user_state_key, see SSO::Configuration for more info.')
    end
    attr_writer :user_state_key

    # Client

    def session_backend
      @session_backend || default_session_backend
    end
    attr_writer :session_backend

    def passport_verification_timeout_ms
      @passport_verification_timeout_ms || default_passport_verification_timeout_ms
    end
    attr_writer :passport_verification_timeout_ms

    # Both

    def exception_handler
      @exception_handler || default_exception_handler
    end
    attr_writer :exception_handler

    def passport_chip_key
      @passport_chip_key || fail('You need to configure a secret passport_chip_key, see SSO::Configuration for more info.')
    end
    attr_writer :passport_chip_key

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

    def default_exception_handler
      proc do |exception|
        return unless ::SSO.config.logger
        ::SSO.config.logger.error(self.class) do
          "An internal error occured #{exception.class.name} #{exception.message} #{exception.backtrace[0..5].join(' ') if exception.backtrace}"
        end
      end
    end

    def default_human_readable_location_for_ip
      proc do |ip|
        'Unknown'
      end
    end

    def default_session_backend
      fail('You need to configure session_backend, see SSO::Configuration for more info.') unless %w(developmen test).include?(environment)
     # Moneta.new :Memory
    end

    def default_passport_verification_timeout_ms
      100
    end

  end
end
