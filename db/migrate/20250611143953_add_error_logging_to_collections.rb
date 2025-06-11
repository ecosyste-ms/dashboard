class AddErrorLoggingToCollections < ActiveRecord::Migration[8.0]
  def change
    add_column :collections, :last_error_message, :text
    add_column :collections, :last_error_backtrace, :text
    add_column :collections, :last_error_at, :datetime
  end
end
