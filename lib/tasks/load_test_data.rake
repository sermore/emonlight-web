
desc "Load test data produced by fixtures"

task :load_test_data => :environment do

	# sql_lines = File.read("test-data.sql").split(/;[ \t]*$/)
 #  if sql_lines.respond_to?(:each)
 #  	sql_lines.each do |line|
 #      ActiveRecord::Base.connection.execute "#{line};"
 #    end
 #  end
	ActiveRecord::Base.connection.execute(File.read("test-data.sql"))
end