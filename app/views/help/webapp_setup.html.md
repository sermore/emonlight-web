
Web application for the collection and visualization of energy meter information provided by [Emonlight energy meter probe](https://github.com/sermore/emonlight).

The application is build with Ruby on Rails, and it depends strictly on Postgresql database.

In the typical home usage, monitoring a small number of source nodes, it can run smoothly in a Raspberry 2.


Ruby on Rails
-------------

This application requires:

- Ruby 2.3.1
- Rails 4.2.6
- Postgresql Database

Learn more about installing Rails [here](http://railsapps.github.io/installing-rails.html) or [here](https://www.digitalocean.com/community/tutorials/how-to-install-ruby-on-rails-with-rbenv-on-ubuntu-14-04).

Getting Started
---------------

Prerequisite packages for Debian/Ubuntu
    sudo apt-get install git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev python-software-properties libffi-dev
install postgresql database
    sudo apt-get install postgresql postgresql-contrib
Follow setup instructions [here](https://help.ubuntu.com/community/PostgreSQL).

For development, create db user emonlight
    sudo -u postgres createuser --superuser emonlight
    sudo -u postgres psql
change emonlight password to `emonlight`
    postgres=# \password emonlight

install [rbenv](https://github.com/rbenv/rbenv) following instructions on github page.

install [ruby-build](https://github.com/rbenv/ruby-build) following instructions on github page.

install ruby version
    rbenv install 2.3.1
configure gem to skip documentation and install bundler
    echo "gem: --no-ri --no-rdoc" >> ~/.gemrc
    gem install bundler
install node.js package from Debian/Ubuntu
    sudo add-apt-repository ppa:chris-lea/node.js
    sudo apt-get update
    sudo apt-get install nodejs
install bundler gem and refresh rbenv commands
    gem install bundler
    rbenv rehash
clone git repository into directory `emonlight-web`
    git clone git://github/sermore/emonlight-web
install all required gems
    cd emonlight-web
    bundle install
now your installation is complete, you can try the development environment running the bundled server
    rake db:create
    rake db:migrate
    rails s

Configuration
-------------

Production environment setup is handled with the following environment variables (shell variables): 

* database: `OPENSHIFT_APP_NAME`
* username: `OPENSHIFT_POSTGRESQL_DB_USERNAME`
* password: `OPENSHIFT_POSTGRESQL_DB_PASSWORD`
* host: `OPENSHIFT_POSTGRESQL_DB_HOST`
* port: `OPENSHIFT_POSTGRESQL_DB_PORT`
* admin name: `ADMIN_NAME`
* admin email: `ADMIN_EMAIL`
* admin password: `ADMIN_PASSWORD`
* email provider username: `EMAIL_USERNAME`
* email provider password: `EMAIL_PASSWORD`
* email server address: `EMAIL_SERVER_ADDRESS`
* email server port: `EMAIL_SERVER_PORT`
* email server authentication: `EMAIL_SERVER_AUTHENTICATION`
* domain name: `DOMAIN_NAME`
* web domain name: `WEB_DOMAIN_NAME`
* secret key base: `OPENSHIFT_SECRET_TOKEN`


Credits
-------

This application was generated with the [rails_apps_composer](https://github.com/RailsApps/rails_apps_composer) gem
provided by the [RailsApps Project](http://railsapps.github.io/).

Rails Composer is open source and supported by subscribers. Please join RailsApps to support development of Rails Composer.

License
-------

GNU GENERAL PUBLIC LICENSE Version 3
