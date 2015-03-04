class SessionsController < ApplicationController

  def new
    return_path = env['warden.options'][:attempted_path]
    Rails.logger.debug { "Remembering the return path #{return_path.inspect}"}
    session[:return_path] = return_path
  end

  def create
    warden.authenticate! :password

    if session[:return_path]
      Rails.logger.debug { "Sending tou back to #{session[:return_path]}" }
      redirect_to session[:return_path]
      session[:return_path] = nil
    else
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
