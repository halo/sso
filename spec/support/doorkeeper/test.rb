module Doorkeeper
  module Test

    def self.setup
      Doorkeeper::Application.create! name: 'Alpha', redirect_uri: alpha_redirect_uri, uid: alpha_id, secret: alpha_secret
      Doorkeeper::Application.create! name: 'Beta',  redirect_uri: beta_redirect_uri,  uid: beta_id,  secret: beta_secret
    end

    def self.alpha_id
      '087e7eba0ab22099a6f8864aefd2472ffba2376ab2ebe090d9917c5d63b9ac45'
    end

    def self.alpha_secret
      '1ce7d7ce7fbd76abafdfa0d0b33ad77e454ecd05f4ed613e5efd12f7fbf89b8a'
    end

    def self.alpha_redirect_uri
      'https://alpha.example.com/auth/sso/callback'
    end

    def self.beta_id
      'afb5b8ff6d708e36c315ede59418cedf57a1f4c8807d9028ac450ddb131cefcd'
    end

    def self.beta_secret
      '431ed0d33aad86dc10790547243662616444a106d4817069a4577a4ee875ce59'
    end

    def self.beta_redirect_uri
      'https://beta.example.com/cms/auth/sso/callback'
    end

  end
end
