FactoryBot.define do
  factory :transaction do
    collective_id { 1 }
    sequence(:uuid) { |n| "txn-uuid-#{n}" }
    amount { 100 }
    net_amount { 100 }
    created_at { 1.day.ago }
    transaction_kind { "CONTRIBUTION" }
    account { "testaccount" }

    trait :expense do
      amount { -50 }
      net_amount { -50 }
      transaction_kind { "EXPENSE" }
      transaction_expense_type { "DEVELOPMENT" }
    end

    trait :donation do
      transaction_kind { "CONTRIBUTION" }
    end
  end
end