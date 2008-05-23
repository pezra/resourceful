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
  header = YAML.load(env['QUERY_STRING'].gsub('%20', ' '))
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

# first request is a 200, every one after that is 304
NotModifiedResponder = lambda do |env|
  @@been_here_before = 0 unless defined? @@been_here_before
  @@been_here_before += 1

  header = {'X-Been-Here-Before' => @@been_here_before.to_s}
  if @@been_here_before > 1
    [ 304, header, [] ]
  else
    body = [header.inspect]
    header.merge!({
            'Content-Type' => 'text/plain', 
            'Content-Length' => body.join.size.to_s
    })

    [ 200, header, body ]
  end

end unless defined? NotModifiedResponder


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
      map( '/200_then_304' ){ run NotModifiedResponder }
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
