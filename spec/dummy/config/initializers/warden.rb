# POI
::Warden::Strategies.add :password do
  def valid?
    params['username'].present?
  end

  def authenticate!
    Rails.logger.debug 'Authenticating from username and password...'

    user = ::User.authenticate params['username'], params['password']

    if user
      Rails.logger.debug { 'Authentication from username and password successful.' }
      success! user
    else
      Rails.logger.debug { 'Authentication from username and password failed.' }
      fail! 'Could not login.'
    end
  end
end

# POI
Warden::Manager.after_authentication do |user, warden, options|
  Rails.logger.debug { 'Running Wardens after_authentication hook' }
  request = warden.request
  session = warden.env['rack.session']

  Rails.logger.debug { "Generating a passport for user #{user.id.inspect} for the session cookie at the SSO server..." }
  attributes = { owner_id: user.id, ip: request.ip, agent: request.user_agent }

  generation = SSO::Server::Passports.generate attributes
  if generation.success?
    Rails.logger.debug { "Passport with ID #{generation.object.inspect} generated successfuly."}
    session[:passport_id] = generation.object
  else
    fail generation.code.inspect + generation.object.inspect
  end

  Rails.logger.debug 'Wardens after_authentication hook has finished'
end
