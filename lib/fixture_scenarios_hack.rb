class Test::Unit::TestCase 
  def self.scenario_with_builder(*args)
    # try to build ruby driven scenarios
    if File.exists? scenarios_rb = File.join(fixture_path, 'scenarios.rb')
      require scenarios_rb
    end
    scenario_without_builder(*args)
  end

  class << self
    alias_method_chain :scenario, :builder
  end
end
