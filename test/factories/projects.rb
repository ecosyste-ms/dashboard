FactoryBot.define do
  factory :project do
    sequence(:url) { |n| "https://github.com/example/test-repo-#{n}" }
    last_synced_at { 1.hour.ago }
    sync_status { "completed" }
    
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

    # Real-world project factories based on actual ecosystems data
    trait :rails_project do
      url { "https://github.com/rails/rails" }
      repository do
        {
          "full_name" => "rails/rails",
          "name" => "rails",
          "owner" => "rails",
          "description" => "Ruby on Rails",
          "language" => "Ruby",
          "stargazers_count" => 56000,
          "forks_count" => 21000,
          "subscribers_count" => 2400,
          "archived" => false,
          "fork" => false,
          "created_at" => "2008-04-11T02:19:47Z",
          "pushed_at" => "2024-01-15T10:30:00Z",
          "html_url" => "https://github.com/rails/rails",
          "default_branch" => "main",
          "host" => {
            "name" => "GitHub",
            "kind" => "git"
          },
          "manifests_url" => "https://repos.ecosyste.ms/api/v1/hosts/GitHub/repositories/rails/rails/manifests",
          "last_synced_at" => "2024-01-15T12:00:00Z",
          "metadata" => {
            "files" => {
              "readme" => "README.md"
            },
            "funding" => {
              "tidelift" => "gem/rails"
            }
          }
        }
      end
    end

    trait :fastlane_project do
      url { "https://github.com/fastlane/fastlane" }
      repository do
        {
          "full_name" => "fastlane/fastlane",
          "name" => "fastlane",
          "owner" => "fastlane",
          "description" => "🚀 The easiest way to automate building and releasing your iOS and Android apps",
          "language" => "Ruby", 
          "stargazers_count" => 39000,
          "forks_count" => 5800,
          "subscribers_count" => 900,
          "archived" => false,
          "fork" => false,
          "created_at" => "2014-11-05T10:30:00Z",
          "pushed_at" => "2024-01-14T15:20:00Z",
          "html_url" => "https://github.com/fastlane/fastlane",
          "default_branch" => "master",
          "host" => {
            "name" => "GitHub",
            "kind" => "git"
          },
          "manifests_url" => "https://repos.ecosyste.ms/api/v1/hosts/GitHub/repositories/fastlane/fastlane/manifests",
          "last_synced_at" => "2024-01-14T16:00:00Z",
          "metadata" => {
            "files" => {
              "readme" => "README.md"
            },
            "funding" => {
              "opencollective" => "fastlane"
            }
          }
        }
      end
    end

    trait :typescript_project do
      url { "https://github.com/microsoft/TypeScript" }
      repository do
        {
          "full_name" => "microsoft/TypeScript",
          "name" => "TypeScript",
          "owner" => "microsoft",
          "description" => "TypeScript is a superset of JavaScript that compiles to clean JavaScript output.",
          "language" => "TypeScript",
          "stargazers_count" => 100000,
          "forks_count" => 12000,
          "subscribers_count" => 3200,
          "archived" => false,
          "fork" => false,
          "created_at" => "2012-10-01T15:00:00Z",
          "pushed_at" => "2024-01-16T09:45:00Z",
          "html_url" => "https://github.com/microsoft/TypeScript",
          "default_branch" => "main",
          "host" => {
            "name" => "GitHub",
            "kind" => "git"
          },
          "manifests_url" => "https://repos.ecosyste.ms/api/v1/hosts/GitHub/repositories/microsoft/TypeScript/manifests",
          "last_synced_at" => "2024-01-16T10:00:00Z",
          "metadata" => {
            "files" => {
              "readme" => "README.md"
            }
          }
        }
      end
    end

    trait :with_sync_timestamps do
      issues_last_synced_at { 1.hour.ago }
      commits_last_synced_at { 2.hours.ago }
      tags_last_synced_at { 3.hours.ago }
      packages_last_synced_at { 30.minutes.ago }
      dependencies_last_synced_at { 45.minutes.ago }
    end

    trait :never_synced do
      last_synced_at { nil }
      issues_last_synced_at { nil }
      commits_last_synced_at { nil }
      tags_last_synced_at { nil }
      packages_last_synced_at { nil }
      dependencies_last_synced_at { nil }
    end
  end
end