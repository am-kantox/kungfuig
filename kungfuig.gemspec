# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kungfuig/version'

Gem::Specification.new do |spec|
  spec.name          = 'kungfuig'
  spec.version       = Kungfuig::VERSION
  spec.authors       = ['Kantox LTD']
  spec.email         = ['aleksei.matiushkin@kantox.com']
  spec.licenses      = ['MIT']

  spec.summary       = 'Simple but powerful config for any gem.'
  spec.description   = 'Config with goodnesses.'
  spec.homepage      = 'http://kantox.com'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # spec.metadata['allowed_push_host'] = 'http://mygemserver.com' if spec.respond_to?(:metadata)

  spec.add_dependency 'hashie', '~> 3'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'pry', '~> 0.10'

  spec.add_development_dependency 'rspec', '~> 2.12'
  spec.add_development_dependency 'cucumber', '~> 1.3'
  spec.add_development_dependency 'yard', '~> 0'
end
