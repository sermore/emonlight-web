# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
user = CreateAdminService.new.call
puts 'CREATED ADMIN USER: ' << user.email

case Rails.env 
when "development"

	# u = User.create(email: "me@home.com", password: "password")
	u = User.find(1)
	n = Node.create(user: u, title: "Node 1")
	u.update(node: n)

when "production"
end