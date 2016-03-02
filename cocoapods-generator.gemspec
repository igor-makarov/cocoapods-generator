# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-generator/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-generator'
  spec.version       = CocoapodsGenerator::VERSION
  spec.authors       = ['从权']
  spec.email         = ['chaoyang.zcy@alibaba-inc.com']
  spec.description   = %q{Config empty target with configuration from *.podspec.}
  spec.summary       = %q{add files to empty target from *.podspec, such as souce files, libraries, frameworks, resources and so on.}
  spec.homepage      = 'https://github.com/zhzhy/cocoapods-generator'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency "cocoapods", ">= 0.38.2"

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end
