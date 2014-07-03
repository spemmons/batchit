require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/test/'
  add_filter '/config/'
end

SimpleCov.merge_timeout 900


# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require File.expand_path('../dummy/config/environment.rb',  __FILE__)
require 'rails/test_help'

Rails.backtrace_cleaner.remove_silencers!

ActiveRecord::Schema.define do

  ActiveRecord::Base.connection.tables.each{|table_name| ActiveRecord::Base.connection.drop_table table_name}

  create_table :parent_models do |t|
    t.integer :child_id
    t.string  :name
  end

  create_table :child_models do |t|
    t.string  :name
  end

end

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
