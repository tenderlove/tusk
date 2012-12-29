# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "tusk"
  s.version = "1.1.0.20121229121018"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Aaron Patterson"]
  s.date = "2012-12-29"
  s.description = "Tusk is a minimal pub / sub system with multiple observer strategies.\nTusk builds upon the Observer API from stdlib in order to provide a mostly\nconsistent API for building cross thread or process pub / sub systems.\n\nCurrently, Tusk supports Redis and PostgreSQL as message bus back ends."
  s.email = ["aaron@tenderlovemaking.com"]
  s.extra_rdoc_files = ["CHANGELOG.rdoc", "Manifest.txt", "CHANGELOG.rdoc", "README.markdown"]
  s.files = [".autotest", "CHANGELOG.rdoc", "Manifest.txt", "README.markdown", "Rakefile", "lib/tusk.rb", "lib/tusk/latch.rb", "lib/tusk/observable/drb.rb", "lib/tusk/observable/pg.rb", "lib/tusk/observable/redis.rb", "test/helper.rb", "test/observable/test_drb.rb", "test/observable/test_pg.rb", "test/observable/test_redis.rb", "test/redis-test.conf", "tusk.gemspec", ".gemtest"]
  s.homepage = "http://github.com/tenderlove/tusk"
  s.rdoc_options = ["--main", "README.markdown"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "tusk"
  s.rubygems_version = "2.0.0.preview3"
  s.summary = "Tusk is a minimal pub / sub system with multiple observer strategies"
  s.test_files = ["test/observable/test_drb.rb", "test/observable/test_pg.rb", "test/observable/test_redis.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<minitest>, ["~> 4.3"])
      s.add_development_dependency(%q<rdoc>, ["~> 3.10"])
      s.add_development_dependency(%q<pg>, ["~> 0.14.0"])
      s.add_development_dependency(%q<hoe>, ["~> 3.3"])
    else
      s.add_dependency(%q<minitest>, ["~> 4.3"])
      s.add_dependency(%q<rdoc>, ["~> 3.10"])
      s.add_dependency(%q<pg>, ["~> 0.14.0"])
      s.add_dependency(%q<hoe>, ["~> 3.3"])
    end
  else
    s.add_dependency(%q<minitest>, ["~> 4.3"])
    s.add_dependency(%q<rdoc>, ["~> 3.10"])
    s.add_dependency(%q<pg>, ["~> 0.14.0"])
    s.add_dependency(%q<hoe>, ["~> 3.3"])
  end
end
