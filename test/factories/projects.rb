FactoryBot.define do
  factory :project do
    url { "https://github.com/example/test-repo" }
    last_synced_at { 1.hour.ago }
    
    trait :with_repository do
      repository do
        {
          "full_name" => "example/test-repo",
          "name" => "test-repo",
          "owner" => "example",
          "description" => "A test repository",
          "language" => "Ruby",
          "stargazers_count" => 100,
          "forks_count" => 10,
          "subscribers_count" => 5,
          "archived" => false,
          "fork" => false,
          "created_at" => "2020-01-01T00:00:00Z",
          "pushed_at" => "2024-01-01T00:00:00Z",
          "html_url" => "https://github.com/example/test-repo",
          "default_branch" => "main",
          "host" => {
            "name" => "GitHub",
            "kind" => "git"
          },
          "last_synced_at" => "2024-01-01T12:00:00Z"
        }
      end
    end

    trait :without_repository do
      repository { nil }
    end

    trait :with_issues_synced do
      issues_last_synced_at { 2.hours.ago }
    end
  end
end