require File.expand_path('../lib/norm/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Timothy Leslie Allen", "Arlen Christian Mart Cuss"]
  gem.email         = ["allen.timothy.email@gmail.com", "ar@len.me"]
  gem.description   = %q{Norm's not an ORM}
  gem.summary       = %q{NOT an ORM.}
  gem.homepage      = "https://github.com/unnali/norm" # TBD

  gem.add_dependency('pg')
  gem.add_development_dependency('rake')
  gem.add_development_dependency('rspec')

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "norm"
  gem.require_paths = ["lib"]
  gem.version       = Norm::VERSION
end

# vim: set sw=2 et cc=80:
