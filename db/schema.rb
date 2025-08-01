# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_31_121918) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "advisories", force: :cascade do |t|
    t.integer "project_id"
    t.string "uuid"
    t.string "url"
    t.string "title"
    t.text "description"
    t.string "origin"
    t.string "severity"
    t.datetime "published_at"
    t.datetime "withdrawn_at"
    t.string "classification"
    t.float "cvss_score"
    t.string "cvss_vector"
    t.string "references", default: [], array: true
    t.string "source_kind"
    t.string "identifiers", default: [], array: true
    t.jsonb "packages", default: []
    t.string "repository_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "blast_radius"
    t.float "epss_percentage"
    t.float "epss_percentile"
  end

  create_table "collection_projects", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.bigint "project_id", null: false
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["collection_id", "project_id"], name: "index_collection_projects_on_collection_id_and_project_id", unique: true
    t.index ["collection_id"], name: "index_collection_projects_on_collection_id"
    t.index ["deleted_at"], name: "index_collection_projects_on_deleted_at"
    t.index ["project_id"], name: "index_collection_projects_on_project_id"
  end

  create_table "collections", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.string "visibility", default: "public"
    t.integer "user_id", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.string "github_organization_url"
    t.string "collective_url"
    t.string "github_repo_url"
    t.text "dependency_file"
    t.string "sync_status", default: "pending", null: false
    t.text "last_error_message"
    t.text "last_error_backtrace"
    t.datetime "last_error_at"
    t.string "import_status", default: "pending"
    t.datetime "last_synced_at"
    t.integer "direct_dependencies_count", default: 0, null: false
    t.integer "development_dependencies_count", default: 0, null: false
    t.integer "transitive_dependencies_count", default: 0, null: false
    t.index ["user_id"], name: "index_collections_on_user_id"
  end

  create_table "collectives", force: :cascade do |t|
    t.string "uuid"
    t.string "slug"
    t.string "name"
    t.string "description"
    t.string "tags", default: [], array: true
    t.string "website"
    t.string "github"
    t.string "twitter"
    t.string "repository_url"
    t.json "social_links"
    t.string "currency"
    t.integer "projects_count"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "transactions_count"
    t.float "balance"
    t.string "account_type"
    t.json "owner"
    t.datetime "last_project_activity_at"
    t.boolean "archived"
    t.boolean "no_funding"
    t.boolean "no_license"
    t.string "host"
    t.datetime "collective_created_at"
    t.datetime "collective_updated_at"
    t.float "total_donations"
    t.index ["slug"], name: "index_collectives_on_slug", unique: true
  end

  create_table "commits", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "sha"
    t.string "message"
    t.datetime "timestamp"
    t.boolean "merge"
    t.string "author"
    t.string "committer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "additions"
    t.integer "deletions"
    t.integer "files_changed"
    t.index ["project_id", "sha"], name: "index_commits_on_project_id_and_sha", unique: true
    t.index ["project_id"], name: "index_commits_on_project_id"
  end

  create_table "issues", force: :cascade do |t|
    t.integer "project_id"
    t.string "uuid"
    t.string "node_id"
    t.integer "number"
    t.string "state"
    t.string "title"
    t.string "body"
    t.string "user"
    t.string "assignees"
    t.boolean "locked"
    t.integer "comments_count"
    t.boolean "pull_request"
    t.datetime "closed_at"
    t.string "closed_by"
    t.string "author_association"
    t.string "state_reason"
    t.integer "time_to_close"
    t.datetime "merged_at"
    t.json "dependency_metadata"
    t.string "html_url"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "labels", default: [], array: true
    t.index ["project_id", "number"], name: "index_issues_on_project_id_and_number", unique: true
    t.index ["project_id"], name: "index_issues_on_project_id"
  end

  create_table "packages", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "name"
    t.string "ecosystem"
    t.string "purl"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_packages_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "url"
    t.json "repository"
    t.string "keywords", default: [], array: true
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "issues_count", default: 0
    t.text "readme"
    t.integer "collective_id"
    t.integer "packages_count"
    t.json "dependencies"
    t.datetime "issues_last_synced_at"
    t.datetime "tags_last_synced_at"
    t.json "github_sponsors", default: {}
    t.datetime "commits_last_synced_at"
    t.datetime "packages_last_synced_at"
    t.datetime "dependencies_last_synced_at"
    t.string "sync_status", default: "pending", null: false
    t.integer "direct_dependencies_count", default: 0, null: false
    t.integer "development_dependencies_count", default: 0, null: false
    t.integer "transitive_dependencies_count", default: 0, null: false
    t.index ["collective_id"], name: "index_projects_on_collective_id"
    t.index ["url"], name: "index_projects_on_url", unique: true
  end

  create_table "sboms", force: :cascade do |t|
    t.text "raw"
    t.text "converted"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tags", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "name"
    t.string "sha"
    t.string "kind"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "html_url"
    t.index ["project_id", "name"], name: "index_tags_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_tags_on_project_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "collective_id"
    t.string "uuid"
    t.float "amount"
    t.float "net_amount"
    t.string "transaction_type"
    t.string "currency"
    t.string "account"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "transaction_kind"
    t.string "transaction_expense_type"
    t.string "from_account"
    t.string "to_account"
    t.index ["collective_id"], name: "index_transactions_on_collective_id"
    t.index ["uuid"], name: "index_transactions_on_uuid", unique: true
  end

  create_table "user_projects", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "project_id", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_user_projects_on_deleted_at"
    t.index ["project_id"], name: "index_user_projects_on_project_id"
    t.index ["user_id", "project_id"], name: "index_user_projects_on_user_id_and_project_id", unique: true
    t.index ["user_id"], name: "index_user_projects_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "collection_projects", "collections"
  add_foreign_key "collection_projects", "projects"
  add_foreign_key "user_projects", "projects"
  add_foreign_key "user_projects", "users"
end
