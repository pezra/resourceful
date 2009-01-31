
require 'sinatra'

Sinatra::Default.set(
  :environment => :test,
  :run => false,
  :raise_errors => true,
  :logging => false
)

def any(path, opts={}, &blk)
  %w[head get post put delete].each do |verb|
    send verb, path, opts, &blk
  end
end

get '/' do
  "Hello, world!"
end

post '/' do
  request.body
end

put '/' do
  request.body
end

delete '/' do
  "Deleted"
end

# Responds with the method used for the request
any '/method' do
  request.env['REQUEST_METHOD']
end

# Responds with the response code in the url
any '/code/:code' do
  status params[:code]
  params[:code]
end

# Sets the response header from the query string, and
# dumps the request header into the body as yaml for inspection
any '/header' do
  params.each { |k,v| response[k] = v }
  response['Content-Type'] ||= "application/yaml"
  request.env.to_yaml
end
  
# Takes a modified=httpdate as a query param, and a If-Modified-Since header, 
# and responds 304 if they're the same
get '/cached' do
  modtime = params[:modified]
  imstime = request.env['If-Modified-Since']

  if modtime == imstime
    status 304
  end
end





require 'thin'
# Spawn the server in another process
@server = fork do
  Thin::Logging.silent = true
  #Thin::Logging.debug = true

  Thin::Server.start(Sinatra::Application)
end

# Kill the server process when rspec finishes
at_exit { Process.kill("TERM", @server) }

# Give the app a change to initialize
$stderr.puts "Waiting for thin to initialize..."
sleep 0.2


