require 'csv'
require 'time'

desc "Import CSV file into pulses table, to be called rake import_pulses[1, filename]"

#namespace :import_rawdata_csv do
task :import_pulses, [:node_id, :file, :format] => :environment do |t, args|
	args.with_defaults(node_id: 1, file: 'emonlight-data.log', format: 't2')
	Pulse.import(args.node_id, args.file, args.format)
end
#end 