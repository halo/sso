FactoryGirl.define do
  factory :parent_of_all_doorkeeper_applications, class: Doorkeeper::Application do

    factory :insider_doorkeeper_application do
      scopes { :insider }
    end

    factory :outsider_doorkeeper_application do
      scopes { :outsider }
    end

    uid          { SecureRandom.hex }
    secret       { SecureRandom.hex }
    name         { %w(Alpha Beta Gamma Delta Epsilon).sample }
    redirect_uri { "https://#{name.downcase}.example.com#{['/subpath', nil].sample}/auth/sso/callback" }

  end
end
