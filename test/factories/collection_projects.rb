FactoryBot.define do
  factory :collection_project do
    collection
    project
    deleted_at { nil }

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end