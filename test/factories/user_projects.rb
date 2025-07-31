FactoryBot.define do
  factory :user_project do
    user
    project
    status { :active }

    trait :removed do
      status { :removed }
    end
  end
end