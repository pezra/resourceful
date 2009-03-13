require 'rubygems'
require 'spec'


$LOAD_PATH << File.join(File.dirname(__FILE__), "..", "lib")
require 'resourceful'

$LOAD_PATH << File.dirname(__FILE__) # ./spec

# Spawn the server in another process

if ! defined?(STUB_SERVER_STARTED)
  STUB_SERVER_STARTED = true

  @server = fork do
    
    require 'simple_sinatra_server'
    Sinatra::Default.set(
      :run => true,
      :logging => false)
  end
end

# Kill the server process when rspec finishes
at_exit { Process.kill("TERM", @server) }

# Give the app a change to initialize
$stderr.puts "Waiting for thin to initialize..."
sleep 0.2

