class RenameKindToAccountType < ActiveRecord::Migration[7.1]
  def change
    rename_column :collectives, :kind, :account_type
  end
end
