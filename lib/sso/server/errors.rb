module SSO
  module Server
    module Errors

      Error = Class.new(StandardError)

      WardenMissing = Class.new(Error)

    end
  end
end
