# ScenarioBuilder

require 'fileutils'

class Object
  def scenario(scenario, &block)
    if block.nil?
      raise NoMethodError, "undefined method `scenario' for #{inspect}"
    else
      ScenarioBuilder.new(scenario, &block).build
    end
  end
  alias_method :build_scenario, :scenario
end

class ScenarioBuilder
  @@record_name_fields = %w( name title username login )

  @@delete_sql = "DELETE FROM %s"
  @@select_sql = "SELECT * FROM %s"

  def initialize(scenario, &block)
    case scenario
    when Hash
      parent    = scenario.values.first
      scenario  = scenario.keys.first
      @scenario = "#{validate_parent(parent)}/#{scenario}" 
    when Symbol, String
      @scenario = scenario.to_s
    else 
      raise "I don't know how to build `#{scenario.inspect}'"
    end

    @block    = block
    @children = []
    @custom_names = {}
  end

  def validate_parent(scenario)
    scenario = scenario.to_s
    unless fixtures_dir_exists?(scenario)
      puts "WARNING: Parent scenario `#{scenario}' doesn't exist.  Typo?"
    end
    scenario
  end

  def say(*messages)
    puts messages.map { |message| "=> #{message}" }
  end

  def build
    return if fixtures_dir_exists? unless rebuild_fixtures?
    say "Building scenario `#{@scenario}'"
    delete_tables
    surface_errors { instance_eval(&@block) }
    FileUtils.rm_rf   fixtures_dir(@scenario) if rebuild_fixtures?
    FileUtils.mkdir_p fixtures_dir(@scenario)
    dump_tables
    build_nested_scenarios
  end

  def build_scenario(scenario, &block)
    @children << ScenarioBuilder.new(scenario, @scenario, &block)
  end

  def build_nested_scenarios
    @children.each { |child| child.build }
  end

  def surface_errors
    yield
  rescue Object => error
    puts 
    say "There was an error building scenario `#{@scenario}'", error.inspect
    puts 
    puts error.backtrace
    puts 
    exit!
  end

  def delete_tables
    tables.each { |t| ActiveRecord::Base.connection.delete(@@delete_sql % t)  }
  end

  def tables
    ActiveRecord::Base.connection.tables - skip_tables
  end

  def skip_tables
    %w( schema_info schema_migrations )
  end
  
  def name(custom_name, model_object)
    key = [model_object.class.name, model_object.id]
    @custom_names[key] = custom_name
    model_object
  end
  
  def names_from_ivars!
    instance_values.each do |var, value|
      name(var, value) if value.is_a? ActiveRecord::Base
    end
  end

  def record_name(record_hash)
    key = [@table_name.classify, record_hash['id'].to_i]
    @record_names << (name = @custom_names[key] || inferred_record_name(record_hash) )
    name
  end

  def inferred_record_name(record_hash)
    @@record_name_fields.each do |try|
      if name = record_hash[try]
        inferred_name = name.underscore.gsub(/\W/, ' ').squeeze(' ').tr(' ', '_')
        count = @record_names.select { |name| name == inferred_name }.size
        return count.zero? ? inferred_name : "#{inferred_name}_#{count}"
      end
    end

    "#{@table_name}_#{@row_index.succ!}"
  end

  def dump_tables
    fixtures = tables.inject([]) do |files, @table_name|
      next files if fixture_file_exists? unless rebuild_fixtures?

      rows = ActiveRecord::Base.connection.select_all(@@select_sql % @table_name)
      next files if rows.empty?

      @row_index      = '000'
      @record_names = []
      fixture_data = rows.inject({}) do |hash, record|
        hash.merge(record_name(record) => record)
      end

      write_fixture_file fixture_data

      files + [File.basename(fixture_file)]
    end
    say "Built scenario `#{@scenario}' with #{fixtures.to_sentence}"
  end

  def write_fixture_file(fixture_data)
    File.open(fixture_file, 'w') do |file|
      file.write fixture_data.to_yaml
    end
  end

  def fixture_file
    fixtures_dir(@scenario, "#{@table_name}.yml")
  end

  def fixtures_dir(*paths)
    File.join(RAILS_ROOT, spec_or_test_dir, 'fixtures', *paths)
  end
  
  def spec_or_test_dir
    File.exists?(File.join(RAILS_ROOT, 'spec')) ? 'spec' : 'test'
  end

  def fixtures_dir_exists?(dir = @scenario)
    File.exists? fixtures_dir(dir)
  end

  def fixture_file_exists?
    File.exists? fixture_file
  end

  def rebuild_fixtures?
    (%w( REBUILD_FIXTURES BUILD_FIXTURES NEW_FIXTURES NF ) & ENV.keys).any? || scenarios_file_changed?
  end

  def scenarios_file_changed?
    can_trigger_rebuild = [
      fixtures_dir('scenarios.rb'),
      File.join(RAILS_ROOT, 'db', 'migrate')
    ]

    can_trigger_rebuild.any? { |file| older_than_scenario? file }
  end

  def older_than_scenario?(file)
    scenario_dir = fixtures_dir(@scenario)
    if File.exists?(file) && File.exists?(scenario_dir)
      File.mtime(file) > File.mtime(scenario_dir)
    end
  end
end
