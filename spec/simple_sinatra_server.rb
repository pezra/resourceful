
require 'sinatra'

def any(path, opts={}, &blk)
  %w[head get post put delete].each do |verb|
    send verb, path, opts, &blk
  end
end

def set_request_params_as_response_header!
  params.each { |k,v| response[k] = v }
end

def set_request_header_in_body!
  response['Content-Type'] ||= "application/yaml"
  headers = request.env.reject { |k,v| !v.is_a?(String) }
  headers.to_yaml
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
  set_request_params_as_response_header!
  set_request_header_in_body!
end

# Sets the response header from the query string, and
# dumps the request header into the body as yaml for inspection
any '/header' do
  set_request_params_as_response_header!
  set_request_header_in_body!
end
  
# Takes a modified=httpdate as a query param, and a If-Modified-Since header, 
# and responds 304 if they're the same
get '/cached' do
  set_request_params_as_response_header!
  set_request_header_in_body!

  response['Last-Modified'] = params[:modified]

  modtime = params[:modified]
  imstime = request.env['HTTP_IF_MODIFIED_SINCE']
  
  if modtime && imstime && modtime == imstime
    status 304
  end
end

Sinatra::Default.set(
  :port => 3000
)

