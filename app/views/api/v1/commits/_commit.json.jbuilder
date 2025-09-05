json.extract! commit, :id, :sha, :message, :author, :committer, :timestamp, :merge, 
              :additions, :deletions, :files_changed, :created_at, :updated_at
json.project_id commit.project_id
json.project_slug commit.project.slug if commit.project