require File.expand_path('../lib/mao/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Timothy Leslie Allen", "Arlen Christian Mart Cuss"]
  gem.email         = ["allen.timothy.email@gmail.com", "ar@len.me"]
  gem.description   = %q{Mao Ain't an ORM}
  gem.summary       = %q{A database access layer.  Currently supports PG.}
  gem.homepage      = "https://github.com/unnali/mao" # TBD

  gem.add_dependency('pg')
  gem.add_development_dependency('rake')
  gem.add_development_dependency('rspec')

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "mao"
  gem.require_paths = ["lib"]
  gem.version       = Mao::VERSION
end

# vim: set sw=2 et cc=80:
