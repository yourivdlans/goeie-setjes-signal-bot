source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

ruby '~> 3.0.3'

gem "ruby-dbus", "~> 0.17"

gem "http", "~> 4.4"

gem "dry-configurable", "~> 0.12.1"

group :test do
  gem "minitest", "~> 5.14"
  gem "byebug", "~> 11.1"
  gem "webmock", "~> 3.12"
end
