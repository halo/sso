class SessionsController < ApplicationController
  include ::SSO::Logging
  delegate :logout, to: :warden

  before_action :prevent_json, only: [:new]

  # POI
  def new
    return_path = env['warden.options'][:attempted_path]
    debug { "Remembering the return path #{return_path.inspect}" }
    session[:return_path] = return_path
  end

  # POI
  def create
    warden.authenticate! :password

    if session[:return_path]
      debug { "Sending you back to #{session[:return_path]}" }
      redirect_to session[:return_path]
      session[:return_path] = nil
    else
      debug { "I don't know where you came from, sending you to #{root_url}" }
      redirect_to root_url
    end
  end

  private

  def prevent_json
    return unless request.format.to_sym == :json
    warn { "This request is asking for JSON where it shouldn't" }
    render status: :unauthorized, json: { status: :error, code: :authentication_failed }
  end

  def warden
    request.env['warden']
  end

end
