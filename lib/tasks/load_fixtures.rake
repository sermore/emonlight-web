require 'active_record/fixtures'

desc "load data"

task :load_fixtures, [:fixtures, :classes] =>  :environment do |t, args|
	base_dir = ActiveRecord::Tasks::DatabaseTasks.fixtures_path
	fixtures = (args.fixtures.is_a? Array) ? args.fixtures : [args.fixtures]
	class_map = {}
	class_map[args.fixtures] = args.classes.constantize
	ActiveRecord::FixtureSet.create_fixtures(base_dir, args.fixtures, class_map)
end