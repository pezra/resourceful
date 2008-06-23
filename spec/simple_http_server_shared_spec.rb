require 'yaml'

# this sets up a very simple http server using thin to be used in specs.
SimpleGet = lambda do |env|
  body = ["Hello, world!"]
  [ 200, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? SimpleGet

SimplePost = lambda do |env|
  body = [env['rack.input'].string]
  [ 201, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? SimplePost

SimplePut = lambda do |env|
  body = [env['rack.input'].string]
  [ 200, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? SimplePut

SimpleDel = lambda do |env|
  body = ["KABOOM!"]
  [ 200, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? SimpleDel

# has the method used in the body of the response
MethodResponder = lambda do |env|
  body = [env['REQUEST_METHOD']]
  [ 200, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? MethodResponder

# has a response code of whatever it was given in the url /code/{123}
CodeResponder = lambda do |env|
  code = env['PATH_INFO'] =~ /([\d]+)/ ? Integer($1) : 404
  body = [code.to_s]

  [ code, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? CodeResponder

# YAML-parses the quesy string (expected hash) and sets the header to that
HeaderResponder = lambda do |env|
  header = YAML.load(URI.unescape(env['QUERY_STRING']))
  body = [header.inspect]

  header.merge!({
            'Content-Type' => 'text/plain', 
            'Content-Length' => body.join.size.to_s
           })

  [ 200, header, body ]
end unless defined? HeaderResponder

# redirect. /redirect/{301|302}?{url}
Redirector = lambda do |env|
  code = env['PATH_INFO'] =~ /([\d]+)/ ? Integer($1) : 404
  location = env['QUERY_STRING']
  body = [location]

  [ code, {'Content-Type' => 'text/plain', 'Location' => location, 'Content-Length' => body.join.size.to_s}, body ]
end unless defined? Redirector

# Returns 304 if 'If-Modified-Since' is after given mod time
ModifiedResponder = lambda do |env|
  modtime = Time.httpdate(URI.unescape(env['QUERY_STRING']))

  code = 200
  if env['HTTP_IF_MODIFIED_SINCE']
    code = 304
  end
  body = [modtime.to_s]

  header = {'Content-Type' => 'text/plain',
            'Content-Length' => body.join.size.to_s,
            'Last-Modified' => modtime.httpdate,
            'Cache-Control' => 'must-revalidate'}

  [ code, header, body ]
end unless defined? ModifiedResponder

require 'rubygems'
require 'httpauth'
AuthorizationResponder = lambda do |env|
  authtype = env['QUERY_STRING']
  header = {}
  if auth_string = env['HTTP_AUTHORIZATION']
    if authtype == "basic" &&
       ['admin', 'secret'] == HTTPAuth::Basic.unpack_authorization(auth_string)
      code = 200
      body = ["Authorized"]
    elsif authtype == "digest" #&&
          credentials = HTTPAuth::Digest::Credentials.from_header(auth_string) &&
          credentials &&
          credentials.validate(:password => 'secret', :method => 'GET')
          puts auth_string.inspect
          puts credentials.inspect
      code = 200
      body = ["Authorized"]
    else
      code = 401
      body = ["Not Authorized"]
    end
  else 
    code = 401
    body = ["Not Authorized"]
    if authtype == "basic"
      header = {'WWW-Authenticate' => HTTPAuth::Basic.pack_challenge('Test Auth')}
    elsif authtype == "digest"
      chal = HTTPAuth::Digest::Credentials.new(:realm => 'Test Auth', :qop => 'auth')
      header = {'WWW-Authenticate' => chal.to_header}
    end
  end

  [ code, header.merge({'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}), body ]
end unless defined? AuthorizationResponder

describe 'simple http server', :shared => true do
  before(:all) do
    #setup a thin http server we can connect to
    require 'thin'
    require 'rack'
    require 'rack/lobster'

    app = Rack::Builder.new do |env|
      use Rack::ShowExceptions

      map( '/get'    ){ run SimpleGet  }
      map( '/post'   ){ run SimplePost }
      map( '/put'    ){ run SimplePut  }
      map( '/delete' ){ run SimpleDel  }

      map( '/method'   ){ run MethodResponder }
      map( '/code'     ){ run CodeResponder }
      map( '/redirect' ){ run Redirector }
      map( '/header'   ){ run HeaderResponder }
      map( '/modified' ){ run ModifiedResponder }
      map( '/auth'     ){ run AuthorizationResponder }
    end

    #spawn the server in a separate thread
    @httpd = Thread.new do
      Thin::Logging.silent = true
      #Thin::Logging.debug = true
      Thin::Server.start(app) 
    end
    #give the server a chance to initialize
    sleep 0.05
  end

  after(:all) do
    # kill the server thread
    @httpd.exit
  end


end
