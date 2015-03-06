require File.expand_path('../boot', __FILE__)

require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'

Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    config.active_record.raise_in_transactional_callbacks = true

    config.log_formatter = proc do |severity, _, progname, message|
      severity = case severity
                 when 'FATAL' then "\e[#31mFATAL\e[0m"
                 when 'ERROR' then "\e[#31mERROR\e[0m"
                 when 'WARN'  then "\e[#33mWARN \e[0m"
                 when 'INFO'  then "\e[#32mINFO \e[0m"
                 when 'DEBUG' then "\e[#35mDEBUG\e[0m"
                 else              severity
      end

      "#{severity.ljust 5} \e[34m#{progname || 'Rails'}\e[0m : #{message}\n"
    end

    # POI
    config.middleware.insert_after ::ActionDispatch::Flash, '::Warden::Manager' do |manager|
      manager.failure_app = SessionsController.action :new
      manager.intercept_401 = false

      manager.serialize_into_session(&:id)
      manager.serialize_from_session { |id| User.find_by_id(id) }
    end

  end
end
