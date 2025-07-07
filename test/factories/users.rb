FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "User #{n}" }
    provider { "github" }
    sequence(:uid) { |n| n.to_s }
    created_at { 1.year.ago }
    updated_at { 1.day.ago }
  end
end