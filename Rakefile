require 'rubygems'
require 'rake'
require 'lib/resourceful'

begin
  require 'echoe'

  Echoe.new('resourceful', Resourceful::VERSION) do |p|
    p.description     = "An HTTP library for Ruby that takes advantage of everything HTTP has to offer."
    p.url             = "http://github.com/paul/resourceful"
    p.author          = "Paul Sadauskas"
    p.email           = "psadauskas@gmail.com"

    p.ignore_pattern  = ["pkg/*", "tmp/*"]
    p.dependencies    = ['addressable', 'httpauth', 'rspec', 'facets', 'andand']
    p.development_dependencies = ['thin', 'yard', 'sinatra']
  end
rescue LoadError => e
  puts "install 'echoe' gem to be able to build the gem"
end

require 'spec/rake/spectask'

desc 'Run all specs'
task :spec => 'spec:all'

namespace :spec do
  def spec_task(name, file_list)
    Spec::Rake::SpecTask.new(name) do |t|
      t.spec_opts << '--options' << 'spec/spec.opts' if File.exists?('spec/spec.opts')
      t.libs << 'lib'
      t.spec_files = file_list
    end
  end

  desc 'Run all specs'
  spec_task(:all, FileList['spec/**/*_spec.rb'])

#   Spec::Rake::SpecTask.new(:all) do |t|
#     t.spec_opts << '--options' << 'spec/spec.opts' if File.exists?('spec/spec.opts')
#     t.libs << 'lib'
#     t.spec_files = 
#   end
  
  desc 'Run acceptance specs'
  spec_task(:acceptance, FileList['spec/acceptance/*_spec.rb'])

#   Spec::Rake::SpecTask.new(:acceptance) do |t|
#     t.spec_opts << '--options' << 'spec/spec.opts' if File.exists?('spec/spec.opts')
#     t.libs << 'lib'
#     t.spec_files = FileList['spec/acceptance/*_spec.rb'] 
#   end

  desc 'Run the specs for the server'
  spec_task(:server, FileList['spec/simple_sinatra_server_spec.rb'])

#   Spec::Rake::SpecTask.new(:server) do |t|
#     t.spec_opts << '--options' << 'spec/spec.opts' if File.exists?('spec/spec.opts')
#     t.libs << 'lib'
#     t.spec_files = FileList['spec/simple_sinatra_server_spec.rb'] 
#   end

end


begin 
  require 'spec/simple_sinatra_server'
  desc "Run the sinatra echo server, with loggin" 
  task :server do
    Sinatra::Default.set(
      :run => true,
      :logging => true
    )
  end
rescue LoadError => e
  puts "Install 'sinatra' gem to run the server"
end

desc 'Default: Run Specs'
task :default => :spec

desc 'Run all tests'
task :test => :spec

begin
  require 'yard'

  desc "Generate Yardoc"
  YARD::Rake::YardocTask.new do |t|
    t.files = ['lib/**/*.rb', 'README.markdown']
  end
rescue LoadError => e
  puts "Install 'yard' gem to generate docs"
end

desc "Update rubyforge documentation"
task :update_docs => :yardoc do
  puts %x{rsync -aPz doc/* psadauskas@resourceful.rubyforge.org:/var/www/gforge-projects/resourceful/}
end

desc "Build the Native extension"
task :build do
  cd 'ext/http11_client' do
    ruby 'extconf.rb'
    system 'make'
  end
end
