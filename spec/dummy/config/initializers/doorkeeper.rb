::Doorkeeper.configure do
  orm :active_record

  #resource_owner_authenticator do
  #  fail 'boom'
  #end

  resource_owner_authenticator &::SSO::Server::Doorkeeper::ResourceOwnerAuthenticator.to_proc

  #resource_owner_from_credentials &::SSO::Server::Doorkeeper::ResourceOwnerFromCredentials.to_proc

  default_scopes  :outsider
  optional_scopes :insider

  skip_authorization do
    true
  end

  admin_authenticator do
    nil
  end
end
