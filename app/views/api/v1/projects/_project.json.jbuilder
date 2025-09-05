json.extract! project, :id, :url, :last_synced_at, :repository, :created_at, :updated_at, :avatar_url, :language
json.keywords project.combined_keywords
json.project_url api_v1_project_url(project, format: :json)

