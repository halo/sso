require 'sso/configuration'

module SSO

  # Public: Lazy-loads and returns the the configuration instance.
  #
  def self.config
    @config ||= ::SSO::Configuration.new
  end

  # Public: Yields the configuration instance.
  #
  def self.configure(&block)
    yield config
  end

end
