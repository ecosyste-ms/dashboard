json.extract! package, :id, :ecosystem, :purl, :name, :metadata, :created_at, :updated_at
json.project_id package.project_id
json.project_slug package.project.slug if package.project