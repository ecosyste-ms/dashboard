FactoryBot.define do
  factory :collection do
    user
    sequence(:name) { |n| "Test Collection #{n}" }
    description { "A test collection for testing purposes" }
    visibility { "public" }
    sequence(:uuid) { |n| SecureRandom.uuid }
    import_status { "completed" }
    sync_status { "ready" }
    sequence(:github_organization_url) { |n| "https://github.com/testorg#{n}#{Time.current.to_i}" }
    
    trait :private do
      visibility { "private" }
    end

    trait :public do
      visibility { "public" }
    end

    trait :with_github_org do
      sequence(:github_organization_url) { |n| "https://github.com/testorg#{n}#{Time.current.to_i}" }
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

    # Real-world collection factories
    trait :ruby_web_frameworks do
      name { "Ruby Web Frameworks" }
      description { "Popular Ruby web application frameworks" }
      visibility { "public" }
      
      after(:create) do |collection|
        rails = create(:project, :rails_project)
        fastlane = create(:project, :fastlane_project)
        
        create(:collection_project, collection: collection, project: rails)
        create(:collection_project, collection: collection, project: fastlane)
      end
    end

    trait :microsoft_ecosystem do
      name { "Microsoft Open Source" }
      description { "Open source projects from Microsoft" }
      visibility { "public" }
      github_organization_url { "https://github.com/microsoft" }
      
      after(:create) do |collection|
        typescript = create(:project, :typescript_project)
        create(:collection_project, collection: collection, project: typescript)
      end
    end

    trait :with_real_github_org do
      name { "Rails Organization" }
      description { "Projects from the Rails GitHub organization" }
      github_organization_url { "https://github.com/rails" }
      visibility { "public" }
    end

    trait :with_collective_funding do
      name { "Open Source Sustainability" }
      description { "Projects with active funding through Open Collective" }
      collective_url { "https://opencollective.com/oss-sustainability" }
      visibility { "public" }
    end

    trait :with_spdx_analysis do
      name { "SPDX Document Analysis" }
      description { "Analysis based on SPDX document data" }
      spdx_url { "https://raw.githubusercontent.com/example/project/main/spdx.json" }
      visibility { "public" }
    end
  end
end