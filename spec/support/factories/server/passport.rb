FactoryGirl.define do
  sequence(:owner_id)  { |n| (n * 2) + 424242 }
  sequence(:ip)        { |n| IPAddr.new("198.51.100.#{n}").to_s }

  factory :parent_of_all_passports, class: SSO::Server::Passport do

    factory :passport do
    end

    owner_id { generate(:owner_id) }
    ip       { generate(:ip) }

  end
end
