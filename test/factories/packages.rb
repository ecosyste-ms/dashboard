FactoryBot.define do
  factory :package do
    association :project
    sequence(:name) { |n| "test-package-#{n}" }
    ecosystem { "npm" }
    sequence(:purl) { |n| "pkg:npm/test-package-#{n}@1.0.0" }
    
    metadata do
      {
        "description" => "A test package for testing purposes",
        "status" => nil,
        "downloads" => 50000,
        "dependents" => 100,
        "dependent_repos_count" => 50,
        "versions_count" => 10,
        "latest_release_number" => "1.2.3",
        "latest_release_published_at" => 2.weeks.ago.iso8601,
        "rankings" => {
          "average" => 2.5
        },
        "licenses" => ["MIT"],
        "homepage" => "https://example.com/test-package",
        "repository_url" => "https://github.com/test/test-package",
        "registry_url" => "https://npmjs.com/package/test-package",
        "maintainers_count" => 3,
        "last_synced_at" => 1.hour.ago.iso8601
      }
    end

    trait :popular do
      metadata do
        {
          "description" => "A very popular test package",
          "status" => nil,
          "downloads" => 500000,
          "dependents" => 5000,
          "dependent_repos_count" => 2500,
          "versions_count" => 25,
          "latest_release_number" => "2.1.0",
          "latest_release_published_at" => 1.week.ago.iso8601,
          "rankings" => {
            "average" => 1.2
          },
          "licenses" => ["MIT"],
          "homepage" => "https://example.com/popular-package",
          "repository_url" => "https://github.com/test/popular-package",
          "registry_url" => "https://npmjs.com/package/popular-package",
          "maintainers_count" => 8,
          "last_synced_at" => 1.hour.ago.iso8601
        }
      end
    end

    trait :npm do
      ecosystem { "npm" }
      sequence(:purl) { |n| "pkg:npm/npm-package-#{n}@1.0.0" }
    end

    trait :ruby do
      ecosystem { "rubygems" }
      sequence(:name) { |n| "ruby-gem-#{n}" }
      sequence(:purl) { |n| "pkg:gem/ruby-gem-#{n}@1.0.0" }
    end

    trait :python do
      ecosystem { "pypi" }
      sequence(:name) { |n| "python-package-#{n}" }
      sequence(:purl) { |n| "pkg:pypi/python-package-#{n}@1.0.0" }
    end
  end
end