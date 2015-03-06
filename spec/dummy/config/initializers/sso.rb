# POI

SSO.configure do |config|

  config.find_user_for_passport = Proc.new do |passport, ip|
    user = User.find_by_id passport.owner_id

    if ip == '198.51.100.74'
      user.some_flags << :is_at_the_office
    else
      user.some_flags << :is_working_from_home
    end

    user
  end

  config.user_state_base = Proc.new { |user| [user.first_name, user.some_tags.sort].join }
  config.user_state_key = 'some_random_secret_token'
end
