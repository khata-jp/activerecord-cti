$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "activerecord/cti/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "activerecord-cti"
  spec.version     = Activerecord::Cti::VERSION
  spec.authors     = ["khata"]
  spec.email       = ["hata_kentaro_es@tokushima-inc.jp"]
  spec.homepage    = "https://bs.tokushima-inc.jp/"
  spec.summary     = "ActiveRecord-Cti is a library implemented Class Table Inheritance on ActiveRecord."
  spec.description = "ActiveRecord-Cti is a library implemented Class Table Inheritance on ActiveRecord. Class Table Inheritance (CTI) is useful under the circumstances that an ActiveRecord object is in multiple positions or has multiple roles, and you want to describe it's structure on the database. For Example, one person may be a player and a coach in a soccer team."
  spec.license     = "MIT"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 6.0.2", ">= 6.0.2.1"

  spec.add_development_dependency "sqlite3"
end
