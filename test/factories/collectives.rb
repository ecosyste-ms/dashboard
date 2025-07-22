FactoryBot.define do
  factory :collective do
    sequence(:slug) { |n| "collective-#{n}" }
    sequence(:name) { |n| "Collective #{n}" }
    sequence(:uuid) { |n| "uuid-#{n}" }
  end
end