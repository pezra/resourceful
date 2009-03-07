require 'rubygems'
require 'spec'
require 'pp'

$LOAD_PATH << File.join(File.dirname(__FILE__), "..", "lib")
$LOAD_PATH << File.join(File.dirname(__FILE__), "..", "ext")
require 'resourceful'

$LOAD_PATH << File.dirname(__FILE__) # ./spec

# Spawn the server in another process

@server = fork do

  require 'simple_sinatra_server'
  Sinatra::Default.set(
    :run => true,
    :logging => false
  )

end

# Kill the server process when rspec finishes
at_exit { Process.kill("TERM", @server) }

# Give the app a change to initialize
$stderr.puts "Waiting for thin to initialize..."
sleep 0.2

