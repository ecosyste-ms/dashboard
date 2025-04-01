class CollectiveProject < ApplicationRecord
  belongs_to :collective
  belongs_to :project
end
