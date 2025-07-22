FactoryBot.define do
  factory :issue do
    project
    sequence(:number) { |n| n }
    pull_request { false }
    created_at { 1.day.ago }
    user { "testuser" }

    trait :pull_request do
      pull_request { true }
    end

    trait :closed do
      closed_at { 1.hour.ago }
    end

    trait :merged do
      pull_request { true }
      merged_at { 1.hour.ago }
      closed_at { 1.hour.ago }
    end

    trait :with_labels do
      labels { ["bug", "feature"] }
    end

    trait :bot_user do
      user { "dependabot[bot]" }
    end

    trait :maintainer do
      author_association { "OWNER" }
    end

    trait :with_time_to_close do
      time_to_close { 1.day.to_i }
    end
  end
end