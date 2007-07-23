if Test::Unit::TestSuite.instance_methods.include? 'run_with_finish'
  require 'scenario_builder'
  require 'fixture_scenarios_hack'
else
  load File.join(File.dirname(__FILE__), 'install.rb')
end
