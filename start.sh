#!/bin/bash

bin/rake db:migrate RAILS_ENV=development
if ! test -e "./config/secrets.yml"; 
    then touch config/secrets.yml;
fi
touch config/secrets.yml
bundle install
rake db:migrate
rake db:seed
