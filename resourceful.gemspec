# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{resourceful}
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Paul Sadauskas"]
  s.date = %q{2008-12-05}
  s.description = %q{An HTTP library for Ruby that takes advantage of everything HTTP has to offer.}
  s.email = %q{psadauskas@gmail.com}
  s.extra_rdoc_files = ["lib/resourceful.rb", "lib/resourceful/authentication_manager.rb", "lib/resourceful/util.rb", "lib/resourceful/resource.rb", "lib/resourceful/memcache_cache_manager.rb", "lib/resourceful/net_http_adapter.rb", "lib/resourceful/http_accessor.rb", "lib/resourceful/stubbed_resource_proxy.rb", "lib/resourceful/header.rb", "lib/resourceful/cache_manager.rb", "lib/resourceful/options_interpreter.rb", "lib/resourceful/response.rb", "lib/resourceful/request.rb", "README.markdown"]
  s.files = ["lib/resourceful.rb", "lib/resourceful/authentication_manager.rb", "lib/resourceful/util.rb", "lib/resourceful/resource.rb", "lib/resourceful/memcache_cache_manager.rb", "lib/resourceful/net_http_adapter.rb", "lib/resourceful/http_accessor.rb", "lib/resourceful/stubbed_resource_proxy.rb", "lib/resourceful/header.rb", "lib/resourceful/cache_manager.rb", "lib/resourceful/options_interpreter.rb", "lib/resourceful/response.rb", "lib/resourceful/request.rb", "spec/acceptance_shared_specs.rb", "spec/spec.opts", "spec/acceptance_spec.rb", "spec/simple_http_server_shared_spec_spec.rb", "spec/spec_helper.rb", "spec/resourceful/header_spec.rb", "spec/resourceful/authentication_manager_spec.rb", "spec/resourceful/memcache_cache_manager_spec.rb", "spec/resourceful/response_spec.rb", "spec/resourceful/options_interpreter_spec.rb", "spec/resourceful/http_accessor_spec.rb", "spec/resourceful/stubbed_resource_proxy_spec.rb", "spec/resourceful/request_spec.rb", "spec/resourceful/resource_spec.rb", "spec/resourceful/cache_manager_spec.rb", "spec/resourceful/net_http_adapter_spec.rb", "spec/simple_http_server_shared_spec.rb", "Manifest", "Rakefile", "README.markdown", "MIT-LICENSE", "resourceful.gemspec"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/paul/resourceful}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Resourceful", "--main", "README.markdown"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{resourceful}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{An HTTP library for Ruby that takes advantage of everything HTTP has to offer.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<addressable>, [">= 0"])
      s.add_runtime_dependency(%q<httpauth>, [">= 0"])
      s.add_runtime_dependency(%q<rspec>, [">= 0"])
      s.add_runtime_dependency(%q<facets>, [">= 0"])
      s.add_runtime_dependency(%q<andand>, [">= 0"])
      s.add_development_dependency(%q<thin>, [">= 0"])
      s.add_development_dependency(%q<yard>, [">= 0"])
    else
      s.add_dependency(%q<addressable>, [">= 0"])
      s.add_dependency(%q<httpauth>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 0"])
      s.add_dependency(%q<facets>, [">= 0"])
      s.add_dependency(%q<andand>, [">= 0"])
      s.add_dependency(%q<thin>, [">= 0"])
      s.add_dependency(%q<yard>, [">= 0"])
    end
  else
    s.add_dependency(%q<addressable>, [">= 0"])
    s.add_dependency(%q<httpauth>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 0"])
    s.add_dependency(%q<facets>, [">= 0"])
    s.add_dependency(%q<andand>, [">= 0"])
    s.add_dependency(%q<thin>, [">= 0"])
    s.add_dependency(%q<yard>, [">= 0"])
  end
end
