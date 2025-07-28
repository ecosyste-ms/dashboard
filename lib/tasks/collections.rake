namespace :collections do
  desc 'sync collections'
  task :sync => :environment do
    Collection.sync_least_recently_synced
  end
end