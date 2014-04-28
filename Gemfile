source 'https://rubygems.org'

gem 'rake'

if RUBY_VERSION.to_f == 1.9
  gem 'activerecord', '~> 3.0'
else
  gem 'activerecord', '>= 4.0'
end

gem 'sqlite3', :platform => [:ruby, :mswin, :mingw]
gem 'jdbc-sqlite3', :platform => :jruby
gem 'activerecord-jdbcsqlite3-adapter', :platform => :jruby

group :development do
  gem 'awesome_print'
  gem 'travis-lint'
end

group :test do
  if RUBY_VERSION.to_f == 1.9
    gem 'minitest', '~> 3.0'
    gem 'shoulda', '~> 2.0'
  else
    gem 'minitest', '~> 4.0'
    gem 'shoulda'
  end
  gem 'mocha'
end
