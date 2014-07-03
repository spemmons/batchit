$:.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'batchit/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'batchit'
  s.version     = Batchit::VERSION
  s.authors     = ['Steve Emmons']
  s.email       = ['s.p.emmons@gmail.com']
  s.homepage    = 'http://spemmons.wordpress.com/'
  s.summary     = 'Support MySQL load data infile'
  s.description = 'Batching insert/update statements in support of belongs_to'

  s.files = Dir['{app,config,lib}/**/*'] + %w(MIT-LICENSE Rakefile README.rdoc)
  s.test_files = Dir["test/**/*"]

  s.add_dependency 'rails', '~> 3.2.18'
end
