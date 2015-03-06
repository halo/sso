secret_key_base = ENV['SSO_CONFIG_SECRET_TOKEN'].presence

if Rails.env.development? || Rails.env.test?
  secret_key_base ||= '1986c60cc8b4843e5a6426d6ef5e1c031be4f73a10b3c56aa9c0b8d2dc8e1eba385975689ca072f5e884c98d178b3e4fde47aa91a9a16173bfaad766905fb7f5'
end

raise 'You must set SSO_CONFIG_SECRET_TOKEN' if secret_key_base.blank?

Rails.application.config.secret_key_base = secret_key_base
