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

  def progname
    'Warden::Strategies.password'
  end
end

# POI
Warden::Manager.after_authentication &::SSO::Server::Warden::Hooks::AfterAuthentication.()
Warden::Strategies.add :password, ::SSO::Server::Warden::Strategies::Passport

#Warden::Strategies.add :password do
#end
