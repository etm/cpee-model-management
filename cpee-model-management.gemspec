Gem::Specification.new do |s|
  s.name             = "cpee-model-management"
  s.version          = "1.0.3"
  s.platform         = Gem::Platform::RUBY
  s.license          = "LGPL-3.0"
  s.summary          = "(Lifecycle) manage your process models in a directory or git repo."

  s.description      = "see http://cpee.org"

  s.files            = Dir['{server/**/*,tools/**/*,lib/**/*}'] + %w(LICENSE Rakefile cpee-model-management.gemspec README.md AUTHORS)
  s.require_path     = 'lib'
  s.extra_rdoc_files = ['README.md']
  s.bindir           = 'tools'
  s.executables      = ['cpee-moma']

  s.required_ruby_version = '>=2.7.0'

  s.authors          = ['Juergen eTM Mangler']

  s.email            = 'juergen.mangler@gmail.com'
  s.homepage         = 'http://cpee.org/'

  s.add_runtime_dependency 'riddl', '~> 0.99'
  s.add_runtime_dependency 'json', '~> 2.1'
end
