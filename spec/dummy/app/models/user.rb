class User < ActiveRecord::Base
  include ::SSO::Logging

  # This is a test implementation only, do not try this at home.
  #
  def self.authenticate(username, password)
    Rails.logger.debug('User') { "Checking password of user #{username.inspect}..." }
    where(email: username, password: password).first
  end

  # Don't try this at home, you should include the *encrypted* password, not the plaintext here.
  #
  def state_base
    result = [email.to_s, password.to_s, tags.map(&:to_s).sort].join
    debug { "The user state base is #{result.inspect}" }
    result
  end

end
