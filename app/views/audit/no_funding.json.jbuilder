json.array! @collectives do |collective|
  json.slug collective.slug
  json.project_url collective.project_url
  json.projects_count collective.projects_count
end