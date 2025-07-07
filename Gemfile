# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development, :test do
  gem "gc_ruboconfig", "~> 5"
  gem "pry", "~> 0.10"
  gem "rails", "~> #{ENV['RAILS_VERSION']}" if ENV["RAILS_VERSION"]
  gem "rspec", "~> 3.13"
  gem "rspec-github", "~> 3.0.0"
  gem "rspec-its", "~> 1.2"
end
