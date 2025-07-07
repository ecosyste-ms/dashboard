FactoryBot.define do
  factory :collection do
    user
    sequence(:name) { |n| "Test Collection #{n}" }
    description { "A test collection for testing purposes" }
    visibility { "public" }
    sequence(:uuid) { |n| SecureRandom.uuid }
    import_status { "completed" }
    sync_status { "ready" }
    github_organization_url { "https://github.com/testorg" }
    
    trait :private do
      visibility { "private" }
    end

    trait :public do
      visibility { "public" }
    end

    trait :with_github_org do
      github_organization_url { "https://github.com/testorg" }
    end

    trait :with_collective do
      collective_url { "https://opencollective.com/testcollective" }
    end

    trait :with_repo do
      github_repo_url { "https://github.com/testuser/testrepo" }
    end

    trait :with_dependency_file do
      dependency_file { "package.json content here" }
    end

    trait :syncing do
      import_status { "completed" }
      sync_status { "syncing" }
    end

    trait :importing do
      import_status { "importing" }
      sync_status { "pending" }
    end

    trait :with_error do
      import_status { "error" }
      sync_status { "error" }
      last_error_message { "Test error message" }
      last_error_at { 1.hour.ago }
    end

    trait :with_projects do
      after(:create) do |collection|
        projects = create_list(:project, 3, :with_repository)
        projects.each do |project|
          create(:collection_project, collection: collection, project: project)
        end
      end
    end
  end
end