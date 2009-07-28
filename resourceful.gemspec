# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{resourceful}
  s.version = "0.5.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Paul Sadauskas"]
  s.date = %q{2009-07-28}
  s.description = %q{An HTTP library for Ruby that takes advantage of everything HTTP has to offer.}
  s.email = %q{psadauskas@gmail.com}
  s.extra_rdoc_files = ["lib/resourceful.rb", "lib/resourceful/net_http_adapter.rb", "lib/resourceful/stubbed_resource_proxy.rb", "lib/resourceful/header.rb", "lib/resourceful/memcache_cache_manager.rb", "lib/resourceful/response.rb", "lib/resourceful/util.rb", "lib/resourceful/options_interpreter.rb", "lib/resourceful/cache_manager.rb", "lib/resourceful/request.rb", "lib/resourceful/resource.rb", "lib/resourceful/exceptions.rb", "lib/resourceful/http_accessor.rb", "lib/resourceful/authentication_manager.rb", "README.markdown"]
  s.files = ["lib/resourceful.rb", "lib/resourceful/net_http_adapter.rb", "lib/resourceful/stubbed_resource_proxy.rb", "lib/resourceful/header.rb", "lib/resourceful/memcache_cache_manager.rb", "lib/resourceful/response.rb", "lib/resourceful/util.rb", "lib/resourceful/options_interpreter.rb", "lib/resourceful/cache_manager.rb", "lib/resourceful/request.rb", "lib/resourceful/resource.rb", "lib/resourceful/exceptions.rb", "lib/resourceful/http_accessor.rb", "lib/resourceful/authentication_manager.rb", "README.markdown", "MIT-LICENSE", "Rakefile", "Manifest", "spec/simple_sinatra_server_spec.rb", "spec/old_acceptance_specs.rb", "spec/acceptance_shared_specs.rb", "spec/spec_helper.rb", "spec/simple_sinatra_server.rb", "spec/acceptance/authorization_spec.rb", "spec/acceptance/header_spec.rb", "spec/acceptance/resource_spec.rb", "spec/acceptance/caching_spec.rb", "spec/acceptance/redirecting_spec.rb", "spec/spec.opts", "resourceful.gemspec"]
  s.homepage = %q{http://github.com/paul/resourceful}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Resourceful", "--main", "README.markdown"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{resourceful}
  s.rubygems_version = %q{1.3.3}
  s.summary = %q{An HTTP library for Ruby that takes advantage of everything HTTP has to offer.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<addressable>, [">= 0"])
      s.add_runtime_dependency(%q<httpauth>, [">= 0"])
      s.add_development_dependency(%q<thin>, [">= 0"])
      s.add_development_dependency(%q<yard>, [">= 0"])
      s.add_development_dependency(%q<sinatra>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
    else
      s.add_dependency(%q<addressable>, [">= 0"])
      s.add_dependency(%q<httpauth>, [">= 0"])
      s.add_dependency(%q<thin>, [">= 0"])
      s.add_dependency(%q<yard>, [">= 0"])
      s.add_dependency(%q<sinatra>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 0"])
    end
  else
    s.add_dependency(%q<addressable>, [">= 0"])
    s.add_dependency(%q<httpauth>, [">= 0"])
    s.add_dependency(%q<thin>, [">= 0"])
    s.add_dependency(%q<yard>, [">= 0"])
    s.add_dependency(%q<sinatra>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 0"])
  end
end
