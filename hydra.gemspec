# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "ngauthier-hydra"
  spec.version       = "0.24.0"
  spec.authors       = ["Nick Gauthier"]
  spec.email         = ["ngauthier@gmail.com"]
  spec.description   = %q{Spread your tests over multiple machines to test your code faster.}
  spec.summary       = %q{Distributed testing toolkit}
  spec.homepage      = "http://github.com/ngauthier/hydra"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "shoulda", "~> 2.10.3"
  spec.add_development_dependency "rspec", "~> 2.0.0.beta.19"
  spec.add_development_dependency "cucumber", "~> 0.9.2"
  spec.add_development_dependency "therubyracer", "~> 0.7.4"
end
