bin/rake db:migrate RAILS_ENV=development
touch config/secrets.yml
bundle install
rake db:migrate
rake db:seed
rails server -b 0.0.0.0
