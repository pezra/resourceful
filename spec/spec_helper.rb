require 'rubygems'
require 'pathname'
require 'spec'
require 'pp'
require 'facets'

$LOAD_PATH << Pathname(__FILE__).dirname + "../lib"
require 'resourceful'

# Only do this shit once, no matter how many times its #require'd
unless @server
  require 'thin'

  # Spawn the server in another process
  @server = fork do
    Thin::Logging.silent = true
    #Thin::Logging.debug = true

    require Pathname(__FILE__).dirname + 'simple_sinatra_server'
    Sinatra::Default.set(
      :environment => :test,
      :run => false,
      :raise_errors => true,
      :logging => ENV["SPEC_LOGGING"] || false
    )

    Thin::Server.start(Sinatra::Application)
  end

  # Kill the server process when rspec finishes
  at_exit { Process.kill("TERM", @server) }

  # Give the app a change to initialize
  $stderr.puts "Waiting for thin to initialize..."
  sleep 0.2
end

