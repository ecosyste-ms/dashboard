json.extract! collection, :id, :name, :description, :slug, :visibility, :created_at, :updated_at
json.projects_count collection.projects.count
json.collection_url api_v1_collection_url(collection, format: :json)