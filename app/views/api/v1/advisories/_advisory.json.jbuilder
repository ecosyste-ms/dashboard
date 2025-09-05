json.extract! advisory, :id, :uuid, :source_kind, :title, :description, :severity, :url,
              :published_at, :withdrawn_at, :references, :cvss_score, :cvss_vector, :created_at, :updated_at
json.project_id advisory.project_id
json.project_slug advisory.project.slug if advisory.project