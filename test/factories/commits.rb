FactoryBot.define do
  factory :commit do
    project
    sequence(:sha) { |n| "abc#{n}123" }
    timestamp { 1.day.ago }
    author { "testauthor" }
    committer { "testcommitter" }
    additions { 10 }
    deletions { 5 }

    trait :merge_commit do
      message { "Merge pull request #123" }
    end
  end
end