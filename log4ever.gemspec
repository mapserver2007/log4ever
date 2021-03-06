# -*- encoding: utf-8 -*-
Gem::Specification.new do |gem|
  gem.authors       = ["mapserver2007"]
  gem.email         = ["mapserver2007@gmail.com"]
  gem.description   = %q{log4ever is simple logger for evernote. It is available as an extension of log4r.}
  gem.summary       = %q{log4ever is simple logger for evernote.}
  gem.homepage      = "https://github.com/mapserver2007/log4ever"
  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "log4ever"
  gem.require_paths = ["lib"]
  gem.add_dependency 'log4r', '~> 1.1', '>= 1.1.10'
  gem.add_dependency 'activesupport', '>= 4.0.0'
  gem.add_dependency 'i18n', '>= 0.7.0'
  gem.add_dependency 'evernote_oauth', '~> 0.2', '>= 0.2.3'
  gem.version       = '0.1.8'
  gem.license       = 'MIT'
end
