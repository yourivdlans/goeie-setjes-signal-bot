source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

ruby '~> 2.6.5'

gem 'sinatra', '~> 2.0'

gem "ruby-dbus", "~> 0.16.0"

gem "http", "~> 4.4"
