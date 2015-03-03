# Don't know why these gems need to be specified here even tough Bundler should take care of it...
# I cannot run e.g. "rake middlware" in the spec/dummy directory unless these are required specifically.
require 'warden'
require 'doorkeeper'

# Just load everthing right away.
require 'sso/configure'
require 'sso/logging'
require 'sso/doorkeeper'
require 'sso/warden/failure_app'
require 'sso/doorkeeper/grant_marker'
require 'sso/engine'

module SSO
end
