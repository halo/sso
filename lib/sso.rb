# Don't know why these gems need to be specified here even tough Bundler should take care of it...
# I cannot run e.g. "rake middlware" in the spec/dummy directory unless these are required specifically.
require 'doorkeeper'
require 'operation'
require 'signature'
require 'warden'

require 'sso/logging'

require 'sso/client/passport'
require 'sso/client/warden/hooks/after_fetch'

require 'sso/server/authentications/passport'
require 'sso/server/warden/hooks/after_authentication'
require 'sso/server/warden/strategies/passport'
require 'sso/server/doorkeeper/resource_owner_authenticator'
require 'sso/server/doorkeeper/grant_marker'
require 'sso/server/doorkeeper/access_token_marker'
require 'sso/server/errors'
require 'sso/server/passport'
require 'sso/server/passports'
require 'sso/server/middleware/passport_verification'
require 'sso/server/geolocations'
require 'sso/server/configuration'
require 'sso/server/configure'
require 'sso/server/engine'

module SSO
  extend ::SSO::Logging
end
