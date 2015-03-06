class User
  include ActiveModel::Model

  attr_accessor :id, :username, :first_name, :some_tags

  def self.find_by_id(id)
    Rails.logger.debug('User') { "Looking up User #{id}..." }
    return unless id.to_i == 42
    new id: 42, username: 'carol', first_name: 'Carol', some_tags: %w(one two three)
  end

  def self.authenticate(username, password)
    Rails.logger.debug('User') { "Checking password of user #{username.inspect}..." }
    return unless username == 'carol' && password == 'p4ssword'
    find_by_id 42
  end

end
