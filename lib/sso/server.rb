require 'rails' # <- Doorkeeper secretly depends on this
require 'doorkeeper'
require 'operation'
require 'httparty'
require 'omniauth'
require 'signature'
require 'warden'

require 'sso'
require 'sso/server/errors'
require 'sso/server/passport'
require 'sso/server/passports'
require 'sso/server/geolocations'
require 'sso/server/engine'

require 'sso/server/authentications/passport'
require 'sso/server/middleware/passport_verification'
require 'sso/server/middleware/passport_destruction'
require 'sso/server/middleware/passport_exchange'

require 'sso/server/warden/hooks/after_authentication'
require 'sso/server/warden/hooks/before_logout'
require 'sso/server/warden/strategies/passport'

require 'sso/server/doorkeeper/resource_owner_authenticator'
require 'sso/server/doorkeeper/grant_marker'
require 'sso/server/doorkeeper/access_token_marker'
