Doorkeeper.configure do
  orm :active_record

  resource_owner_authenticator SSO::Doorkeeper.resource_owner_authenticator

  # https://github.com/doorkeeper-gem/doorkeeper/wiki/Using-Scopes
  default_scopes  :outsider
  optional_scopes :insider

  skip_authorization do
    true
  end

  admin_authenticator do
    nil
  end
end
