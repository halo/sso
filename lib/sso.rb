# Don't know why these gems need to be specified here even tough Bundler should take care of it...
# I cannot run e.g. "rake middlware" in the spec/dummy directory unless these are required specifically.
require 'warden'
require 'doorkeeper'

require 'sso/client/warden'

require 'sso/server/doorkeeper'
require 'sso/server/passports'
require 'sso/server/passports/backend'
require 'sso/server/users'
