require 'rubygems'
require 'rake'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'spec/rake/spectask'

desc 'Default: run unit tests.'
task :default => :spec

desc "Run all tests"
task :test => :spec

desc "Verify Resourceful against it's specs"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.libs << 'lib'
  t.pattern = 'spec/**/*_spec.rb'
end

desc 'Generate documentation for Resourceful.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Resourceful'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

##############################################################################
# Packaging & Installation
##############################################################################

RESOURCEFUL_VERSION = "0.1"

windows = (PLATFORM =~ /win32|cygwin/) rescue nil

SUDO = windows ? "" : "sudo"

task :resourceful => [:clean, :rdoc, :package]

spec = Gem::Specification.new do |s|
  s.name         = "Resourceful"
  s.version      = RESOURCEFUL_VERSION
  s.platform     = Gem::Platform::RUBY
  s.author       = "Peter Williams"
  s.email        = "pezra@barelyenough.org"
  s.homepage     = "https://github.com/pezra/resourceful/tree/master"
  s.summary      = "Resourceful provides a convenient Ruby API for making HTTP requests."
  s.description  = s.summary
  s.require_path = "lib"
  s.files        = %w( LICENSE README Rakefile ) + Dir["{docs,spec,lib}/**/*"]

  # rdoc
  s.has_rdoc         = true
  s.extra_rdoc_files = %w( README LICENSE )

  # Dependencies
  s.add_dependency "mocha"
  s.add_dependency "addressable"
  s.add_dependency "httpauth"
  s.add_dependency "rspec"
  s.add_dependency "json"
  # Requirements
  s.requirements << "install the json gem to get faster json parsing"
  s.required_ruby_version = ">= 1.8.6"
end

Rake::GemPackageTask.new(spec) do |package|
  package.gem_spec = spec
end

desc "Run :package and install the resulting .gem"
task :install => :package do
  sh %{#{SUDO} gem install --local pkg/resourceful-#{VERSION}.gem --no-rdoc --no-ri}
end

desc "Run :package and install the resulting .gem with jruby"
task :jinstall => :package do
  sh %{#{SUDO} jruby -S gem install pkg/resourceful-#{VERSION}.gem --no-rdoc --no-ri}
end

desc "Run :clean and uninstall the .gem"
task :uninstall => :clean do
  sh %{#{SUDO} gem uninstall resourceful}
end

