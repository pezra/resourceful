require 'rubygems'
require 'rake'
require 'echoe'

require 'lib/resourceful'

Echoe.new('resourceful', Resourceful::VERSION) do |p|
  p.description     = "An HTTP library for Ruby that takes advantage of everything HTTP has to offer."
  p.url             = "http://github.com/paul/resourceful"
  p.author          = "Paul Sadauskas"
  p.email           = "psadauskas@gmail.com"

  p.ignore_pattern  = ["pkg/*", "tmp/*"]
  p.dependencies    = ['addressable', 'httpauth', 'rspec', 'facets', 'andand']
  p.development_dependencies = ['thin', 'yard', 'sinatra']
end

require 'spec/rake/spectask'

desc 'Run all specs'
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_opts << '--options' << 'spec/spec.opts' if File.exists?('spec/spec.opts')
  t.libs << 'lib'
  t.spec_files = FileList['spec/acceptance/*_spec.rb'] 
end

desc 'Run the specs for the server'
Spec::Rake::SpecTask.new('spec:server') do |t|
  t.spec_opts << '--options' << 'spec/spec.opts' if File.exists?('spec/spec.opts')
  t.libs << 'lib'
  t.spec_files = FileList['spec/simple_sinatra_server_spec.rb'] 
end

desc "Run the sinatra echo server, with loggin" 
task :server do
  require 'spec/simple_sinatra_server'
  Sinatra::Default.set(
    :run => true,
    :logging => true
  )
end

desc 'Default: Run Specs'
task :default => :spec

desc 'Run all tests'
task :test => :spec

require 'yard'

desc "Generate Yardoc"
YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/**/*.rb', 'README.markdown']
end

desc "Update rubyforge documentation"
task :update_docs => :yardoc do
  puts %x{rsync -aPz doc/* psadauskas@resourceful.rubyforge.org:/var/www/gforge-projects/resourceful/}
end
