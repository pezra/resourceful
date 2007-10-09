require 'rake'
require 'spec/rake/spectask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => :spec

desc "Run all tests"
task :test => :spec

desc "Verify the active_rest plugin against it's specs"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.libs << 'lib'
  t.pattern = 'spec/**/*_spec.rb'
end

desc 'Generate documentation for the advanced_http plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'AdvancedHttp'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
