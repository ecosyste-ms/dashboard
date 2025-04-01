namespace :collectives do
  desc 'sync collectives'
  task sync: :environment do
    Collective.sync_least_recently_synced
  end

  desc 'sync osc collectives'
  task sync_osc: :environment do
    Collective.sync_least_recently_synced_osc
  end

  desc 'discover collectives'
  task :discover => :environment do
    Collective.discover
  end

  desc 'sync funders'
  task sync_funders: :environment do
    Collective.sync_funders
  end
end