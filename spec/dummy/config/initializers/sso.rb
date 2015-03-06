# POI

# This is the minimal configuration you need to do for using the sso gem.

SSO.configure do |config|

  config.find_user_for_passport = proc do |passport, ip|
    # This is your chance to modify the user instance before it is handed out to the OAuth client apps.

    progname = 'SSO.config.find_user_for_passport'
    Rails.logger.debug(progname) { "Looking up User #{passport.owner_id} belonging to Passport #{passport.id} surfing with IP #{ip}..." }
    user = User.find_by_id passport.owner_id
    return unless user

    # The IP address, for example, might be used to set certain flags on the user object.
    # If these flags are included in the #user_state base (see below), all OAuth client apps are immediately aware of the change.
    if ip == '198.51.100.74'
      user.tags << :is_at_the_office
    else
      user.tags << :is_working_from_home
    end

    user
  end

  config.user_state_base = proc do |user|
    # Include the end-user credentials to force all OAuth client apps to refetch the end-user Passports.
    # This way you can revoke all relevant Passports on SSO-logout and the OAuth client apps are immediately aware of it.
    [user.email, user.password, user.tags.sort].join
  end

  # This is a rather static key used to calculate whether a user state changed and needs to be propagated to the OAuth clients.
  # It's not a problem if this changes, as long as it's somewhat deterministic.
  # In our case, we simply derive it from the Rails secret_key_base so we don't have to remember yet another secret somewhere.
  generator = ActiveSupport::KeyGenerator.new Rails.application.config.secret_key_base, iterations: 1000
  config.user_state_key = Rails.application.config.user_state_digest_key = generator.generate_key 'user state digest key'
end
