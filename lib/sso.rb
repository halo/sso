# Don't know why these gems need to be specified here even tough Bundler should take care of it...
# I cannot run e.g. "rake middlware" in the spec/dummy directory unless these are required specifically.
require 'doorkeeper'
require 'operation'
require 'signature'
require 'warden'

require 'sso/logging'
require 'sso/client/passport'
require 'sso/client/warden/after_fetch'
require 'sso/server/doorkeeper/resource_owner_from_credentials'
require 'sso/server/doorkeeper/resource_owner_authenticator'
require 'sso/server/doorkeeper/grant_marker'
require 'sso/server/passports'
require 'sso/server/passports/passport'
require 'sso/server/geolocations'
require 'sso/server/configuration'
require 'sso/server/configure'
require 'sso/server/engine'
