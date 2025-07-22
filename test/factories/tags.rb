FactoryBot.define do
  factory :tag do
    project
    sequence(:name) { |n| "v1.#{n}.0" }
    published_at { 1.day.ago }
  end
end