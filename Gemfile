ruby '2.3.0'
source 'https://rubygems.org'

gem 'pooler', git: 'https://github.com/amancevice/pooler.git'
#gem 'pooler', path: '/Users/amancevice/smallweirdnumber/ruby/pooler'
gem 'rake'
gem 'sinatra'
gem 'sinatra-activerecord',   require: ['sinatra/activerecord', 'sinatra/activerecord/rake']
gem 'sinatra-asset-pipeline', require: ['sinatra/asset_pipeline']
gem 'sinatra-contrib',        require: ['sinatra/cookies']
gem 'sinatra-flash',          require: ['sinatra/flash']

group :development do
  gem 'pry'
  gem 'sqlite3'
end

group :production do
  gem 'pg'
end

