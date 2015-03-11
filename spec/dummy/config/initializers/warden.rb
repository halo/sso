# POI
::Warden::Strategies.add :password do
  def valid?
    params['username'].present?
  end

  def authenticate!
    Rails.logger.debug(progname) { 'Authenticating from username and password...' }

    # Note that at this point you might want to log the end-user IP for the attempted login.
    # That's up to you to solve, but remember one thing:
    # If you both have an untrusted OAuth client (iPhone) and a trusted one (Alpha Rails app)
    # and the login at Alpha is performed using the "Resource Owner Password Credentials Grant"
    # Then you will get Alphas IP, but not the end-users IP. So you might have to pass on the
    # end user IP from Alpha via params. But you cannot trust params, since the iPhone Client
    # is not trusted. Thus, in this particular scenario, you cannot blindly trust params['ip']
    # but you'd have to work with the "insider" and "outsider" doorkeeper application scope
    # restrictions much like SSO::Server::Authentications::Passport#ip does.

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
