# POI

# This is the minimal configuration you need to do for using the sso gem.

SSO.configure do |config|

  config.find_user_for_passport = proc do |passport:|
    # This is your chance to modify the user instance before it is handed out to the OAuth client apps.
    # The Passport has already been updated with the most recent IP metadata, so you can take that into consideration.

    progname = 'SSO.config.find_user_for_passport'
    Rails.logger.debug(progname) { "Looking up User #{passport.owner_id.inspect} belonging to Passport #{passport.id.inspect} surfing with IP #{passport.ip} or #{passport.ip}..." }
    user = User.find_by_id passport.owner_id
    return unless user

    # The IP address, for example, might be used to set certain flags on the user object.
    # Note that the IP can be nil in which case we don't know it.

    if passport.ip == '198.51.100.74'
      user.tags << :is_at_the_office
    elsif passport.ip
      user.tags << :is_working_from_home
    else
      user.tags << :location_is_unknown
    end

    user
  end

  config.user_state_base = proc do |user|
    # Include the end-user credentials to force all OAuth client apps to refetch the end-user Passports.
    # This way you can revoke all relevant Passports on SSO-logout and the OAuth client apps are immediately aware of it.
    user.state_base
  end

  # This is a rather static key used to calculate whether a user state changed and needs to be propagated to the OAuth clients.
  # It's not a problem if this changes, as long as it's somewhat deterministic.
  # In our case, we simply derive it from the Rails secret_key_base so we don't have to remember yet another secret somewhere.
  generator = ActiveSupport::KeyGenerator.new Rails.application.config.secret_key_base, iterations: 1000
  config.user_state_key = Rails.application.config.user_state_digest_key = generator.generate_key 'user state digest key'
end
