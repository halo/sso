FactoryGirl.define do
  factory :parent_of_all_users, class: User do

    factory :user do
    end

    name         { %w(Alice Bob Carol Eve Frank).sample }
    email        { "#{name.downcase}@email.com" }
    password     { %w(p4ssword s3same l3tmein).sample }
    tags         { [[%w(password_expired superuser).sample, %w(admin confirmed).sample], []].sample }
    vip          { [true, false].sample }

  end
end
