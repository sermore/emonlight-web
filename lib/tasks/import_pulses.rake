require 'csv'
require 'time'

desc "Import CSV file into pulses table, to be called rake import_pulses[1, filename]"

#namespace :import_rawdata_csv do
task :import_pulses, [:node_id, :file] => :environment do |t, args|
	Pulse.import(args.node_id, args.file)
end
#end 