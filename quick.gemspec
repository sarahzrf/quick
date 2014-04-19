require './lib/quick'

Gem::Specification.new do |s|
  s.name        = 'quick'
  s.version     = Quick::VERSION
  s.date        = Date.today.to_s
  s.summary     = 'Code in a living environment!'
  s.description = 'A Smalltalk-ish live dev environment for Ruby.'
  s.authors     = ['benzrf']
  s.email       = 'benzrf@benzrf.com'
  s.files       = `git ls-files bin lib *.md LICENSE`.split("\n")
  s.executables = ['quick']
  s.homepage    = 'http://rubygems.org/gems/quick'
  s.license     = 'GPL'

  s.add_runtime_dependency 'rfusefs'
  s.add_runtime_dependency 'ruby_parser'
  s.add_runtime_dependency 'pry-remote-em'
  s.add_runtime_dependency 'brb'
  s.add_runtime_dependency 'thor'
  s.add_runtime_dependency 'git'
  s.add_runtime_dependency 'ffi'
end

