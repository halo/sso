class SessionsController < ApplicationController
  include ::SSO::Logging

  # POI
  def new
    render status: :unauthorized, json: { status: :error, code: :authentication_failed } and return if request.format == :json
    return_path = env['warden.options'][:attempted_path]
    debug { "Remembering the return path #{return_path.inspect}"}
    session[:return_path] = return_path
  end

  # POI
  def create
    warden.authenticate! :password

    if session[:return_path]
      debug { "Sending tou back to #{session[:return_path]}" }
      redirect_to session[:return_path]
      session[:return_path] = nil
    else
      debug { "I don't know where you came from, sending you to #{root_url}" }
      redirect_to root_url
    end
  end

  def logout
    warden.logout
  end

  private

  def warden
    request.env['warden']
  end

end
