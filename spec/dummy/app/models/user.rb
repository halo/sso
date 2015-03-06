class User < ActiveRecord::Base

  # This is a test implementation only, do not try this at home.
  #
  def self.authenticate(username, password)
    Rails.logger.debug('User') { "Checking password of user #{username.inspect}..." }
    where(username: username, password: password).first
  end

end
