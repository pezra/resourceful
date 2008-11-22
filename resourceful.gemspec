Gem::Specification.new do |s|
  s.name = %q{resourceful}
  s.version = "0.2.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Paul Sadauskas", "Peter Williams"]
  s.date = %q{2008-11-22}
  s.email = ["psadauskas@gmail.com", "pezra@barelyenough.org"]
  s.extra_rdoc_files = ["Manifest.txt"]
  s.files = ["MIT-LICENSE", "Manifest.txt", "README.markdown", "Rakefile", "lib/resourceful.rb", "lib/resourceful/authentication_manager.rb", "lib/resourceful/cache_manager.rb", "lib/resourceful/header.rb", "lib/resourceful/http_accessor.rb", "lib/resourceful/net_http_adapter.rb", "lib/resourceful/options_interpreter.rb", "lib/resourceful/request.rb", "lib/resourceful/resource.rb", "lib/resourceful/response.rb", "lib/resourceful/stubbed_resource_proxy.rb", "lib/resourceful/util.rb", "lib/resourceful/version.rb", "resourceful.gemspec", "spec/acceptance_shared_specs.rb", "spec/acceptance_spec.rb", "spec/resourceful/authentication_manager_spec.rb", "spec/resourceful/cache_manager_spec.rb", "spec/resourceful/header_spec.rb", "spec/resourceful/http_accessor_spec.rb", "spec/resourceful/net_http_adapter_spec.rb", "spec/resourceful/options_interpreter_spec.rb", "spec/resourceful/request_spec.rb", "spec/resourceful/resource_spec.rb", "spec/resourceful/response_spec.rb", "spec/resourceful/stubbed_resource_proxy_spec.rb", "spec/simple_http_server_shared_spec.rb", "spec/simple_http_server_shared_spec_spec.rb", "spec/spec.opts", "spec/spec_helper.rb"]
  s.has_rdoc = true
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{resourceful}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{An HTTP library for Ruby that takes advantage of everything HTTP has to offer.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<hoe>, [">= 1.8.2"])
    else
      s.add_dependency(%q<hoe>, [">= 1.8.2"])
    end
  else
    s.add_dependency(%q<hoe>, [">= 1.8.2"])
  end
end
