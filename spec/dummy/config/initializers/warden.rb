# POI
::Warden::Strategies.add :password do
  def valid?
    params['username'].present?
  end

  def authenticate!
    Rails.logger.debug(progname) { 'Authenticating from username and password...' }

    user = ::User.authenticate params['username'], params['password']

    if user
      Rails.logger.debug(progname) { 'Authentication from username and password successful.' }
      success! user
    else
      Rails.logger.debug(progname) { 'Authentication from username and password failed.' }
      fail! 'Could not login.'
    end
  end

  def progname
    'Warden::Strategies.password'
  end
end

# POI
Warden::Manager.after_authentication(&::SSO::Server::Warden::Hooks::AfterAuthentication.to_proc)
Warden::Manager.before_logout(&::SSO::Server::Warden::Hooks::BeforeLogout.to_proc)
Warden::Strategies.add :passport, ::SSO::Server::Warden::Strategies::Passport
