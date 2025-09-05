json.extract! release, :id, :name, :sha, :kind, :published_at, :created_at, :updated_at
json.project_id release.project_id
json.project_slug release.project.slug if release.project