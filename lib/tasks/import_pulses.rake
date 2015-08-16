require 'csv'
require 'time'

desc "Import CSV file into pulses table"

#namespace :import_rawdata_csv do
task :import_pulses, [:user_id, :file] => :environment do |t, args|
	user = User.find(args.user_id)
	Pulse.import(user, args.file)
end
#end 