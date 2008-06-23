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

begin
  gem 'yard', '>=0.2.3'
  require 'yard'
  desc 'Generate documentation for Resourceful.'
  YARD::Rake::YardocTask.new do |t|
    t.files   = ['lib/**/*.rb', 'README']
  end
rescue Exception
  # install YARD to generate documentation
end

desc 'Removes all temporary files'
task :clean

##############################################################################
# Packaging & Installation
##############################################################################

RESOURCEFUL_VERSION = "0.2"

windows = (PLATFORM =~ /win32|cygwin/) rescue nil

SUDO = windows ? "" : "sudo"

task :resourceful => [:clean, :rdoc, :package]

spec = Gem::Specification.new do |s|
  s.name         = "resourceful"
  s.version      = RESOURCEFUL_VERSION
  s.platform     = Gem::Platform::RUBY
  s.author       = "Paul Sadauskas & Peter Williams"
  s.email        = "psadauskas@gmail.com"
  s.homepage     = "https://github.com/paul/resourceful/tree/master"
  s.summary      = "Resourceful provides a convenient Ruby API for making HTTP requests."
  s.description  = s.summary
  s.rubyforge_project = 'resourceful'
  s.require_path = "lib"
  s.files        = %w( MIT-LICENSE README Rakefile ) + Dir["{docs,spec,lib}/**/*"]

  # rdoc
  s.has_rdoc         = true
  s.extra_rdoc_files = %w( README MIT-LICENSE )

  # Dependencies
  s.add_dependency "addressable"
  s.add_dependency "httpauth"
  s.add_dependency "rspec"
  s.add_dependency "thin"
  s.add_dependency "facets"

  s.required_ruby_version = ">= 1.8.6"
end

Rake::GemPackageTask.new(spec) do |package|
  package.gem_spec = spec
end

desc "Run :package and install the resulting .gem"
task :install => :package do
  sh %{#{SUDO} gem install --local pkg/resourceful-#{RESOURCEFUL_VERSION}.gem --no-rdoc --no-ri}
end

desc "Run :package and install the resulting .gem with jruby"
task :jinstall => :package do
  sh %{#{SUDO} jruby -S gem install pkg/resourceful-#{RESOURCEFUL_VERSION}.gem --no-rdoc --no-ri}
end

desc "Run :clean and uninstall the .gem"
task :uninstall => :clean do
  sh %{#{SUDO} gem uninstall resourceful}
end

