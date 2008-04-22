namespace :db do
  namespace :scenario do
    desc 'Build scenarios' 
    task :build => :environment do
      require 'active_record/fixtures'
      require 'fixture_scenarios'
      test_or_spec_dir = File.exists?(File.join(RAILS_ROOT, 'spec')) ? 'spec' : 'test'
      if File.exists? scenarios_rb = File.join(RAILS_ROOT, test_or_spec_dir, 'fixtures', 'scenarios.rb')
        require scenarios_rb
      end
    end
  end
end
