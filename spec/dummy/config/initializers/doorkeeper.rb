::Doorkeeper.configure do

  orm :active_record

  grant_flows %w(authorization_code password)

  resource_owner_authenticator &::SSO::Server::Doorkeeper::ResourceOwnerAuthenticator.()
  resource_owner_from_credentials &::SSO::Server::Doorkeeper::ResourceOwnerAuthenticator.()

  default_scopes  :outsider
  optional_scopes :insider

  skip_authorization do
    true
  end

  admin_authenticator do
    nil
  end

end
