# POI

SSO.configure do |config|

  config.find_user_for_passport = Proc.new do |passport, ip|
    # This is your chance to modify the user instance before it is handed out to the OAuth client apps.
    Rails.logger.debug('SSO.config.find_user_for_passport') { "Looking up User #{passport.owner_id} belonging to Passport with ID #{passport.id} who surfs with IP #{ip}..." }
    return unless user = User.find_by_id(passport.owner_id)

    # The IP address, for example, might be used to set certain flags on the user object.
    # If these flags are included in the #user_state base (see below), all OAuth client apps are immediately aware of the change.
    if ip == '198.51.100.74'
      user.tags << :is_at_the_office
    else
      user.tags << :is_working_from_home
    end

    user
  end

  config.user_state_base = Proc.new do |user|
    # Include the end-user credentials to force all OAuth client apps to refetch the end-user Passports.
    # This way you can revoke all relevant Passports on SSO-logout and the OAuth client apps are immediately aware of it.
    [user.email, user.password, user.tags.sort].join
  end

  # This is a rather static key. You might want to derive it from the secret_key_base if you want to.
  config.user_state_key = 'some_random_secret_token'
end
