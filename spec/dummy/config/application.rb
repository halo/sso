require File.expand_path('../boot', __FILE__)

require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'sprockets/railtie'

Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    config.active_record.raise_in_transactional_callbacks = true

    config.middleware.insert_after ::ActionDispatch::Flash, ::Warden::Manager do |manager|
      manager.failure_app = SessionsController.action :new
      manager.intercept_401 = false

      manager.serialize_into_session { |user| user.id }
      manager.serialize_from_session { |id| User.find_by_id(id) }
    end

  end
end
