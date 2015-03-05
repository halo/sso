SSO.configure do |config|
  config.user_state_base = Proc.new { |user| [user.first_name, user.some_tags.sort].join }
  config.user_state_key = 'some_random_secret_token'
end
