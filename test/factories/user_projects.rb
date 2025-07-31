FactoryBot.define do
  factory :user_project do
    user
    project
    deleted_at { nil }

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end