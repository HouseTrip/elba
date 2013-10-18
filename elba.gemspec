# encoding: UTF-8

lib = File.expand_path('lib')
$:.unshift(lib) unless $:.include?(lib)

require 'elba'

Gem::Specification.new do |s|
  s.name        = "elba"
  s.version     = Elba::VERSION
  s.authors     = ["Marcus Mitchell", "Mark Connell", "Thibault Gautriaud"]
  s.email       = ["marcusleemitchell@gmail.com", "mark@neo.com", "hubbbbb@gmail.com"]
  s.homepage    = "https://github.com/housetrip/elba"
  s.summary     = "Command-line interface for Amazon's ELB"
  s.description = "Command-line interface for Amazon's ELB"

  s.add_development_dependency "bundler"
  s.add_development_dependency "rspec"
  s.add_development_dependency "pry"
  s.add_development_dependency "pry-nav"

  s.add_dependency "fog"
  s.add_dependency "thor"

  s.files        = ["lib/client.rb", "lib/elba.rb"]
  s.executables  = ["elba"]
  s.require_path = 'lib'
end
