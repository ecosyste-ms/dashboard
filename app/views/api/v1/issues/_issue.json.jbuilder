json.extract! issue, :id, :uuid, :number, :title, :body, :state, :html_url, :user, :labels, :pull_request, 
              :created_at, :updated_at, :closed_at, :merged_at, :comments_count, :author_association, :time_to_close
json.bot issue.bot?
json.project_id issue.project_id
json.project_slug issue.project.slug if issue.project