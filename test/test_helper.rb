require 'simplecov'

SimpleCov.start 'rails' do
  add_filter '/test/'
end

SimpleCov.merge_timeout 900

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require 'rails'
require 'batchit'

begin
require File.expand_path('../dummy/config/environment.rb',  __FILE__)
require 'rails/test_help'
rescue
  puts "ERROR:#{$!}\n#{$@.join("\n")}"
end

Rails.backtrace_cleaner.remove_silencers!

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
