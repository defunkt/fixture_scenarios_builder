namespace :db do
  namespace :scenario do
    desc 'Build scenarios' 
    task :build => :environment do
      require 'active_record/fixtures'
      require 'fixture_scenarios'
      if File.exists? scenarios_rb = File.join(RAILS_ROOT, 'test', 'fixtures', 'scenarios.rb')
        require scenarios_rb
      end
    end
  end
end
