# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
    User.delete_all
    User.create(number: '+13122928193', first_name: 'Kong', last_name: 'Lingduo')
    User.create(number: '+17738928145', first_name: 'Castanrda', last_name: 'Adriana')
    User.create(number: '+12242009797', first_name: 'Samer', last_name: 'Sharba')

