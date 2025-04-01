class AddHtmlUrlToTags < ActiveRecord::Migration[7.1]
  def change
    add_column :tags, :html_url, :string
  end
end
