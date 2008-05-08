
describe 'simple http server', :shared => true do
  SimpleGet = lambda do |env|
    body = ["Hello, world!"]
    [ 200, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
  end unless defined?(SimpleGet)

  SimplePost = lambda do |env|
    body = env.inspect
    [ 204, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
  end unless defined?(SimplePost)

  before(:all) do
    #setup a thin http server we can connect to
    require 'thin'

    app = Rack::Builder.new do |env|
      map '/get' do
        run SimpleGet
      end
      map '/post' do
        run SimplePost
      end
    end

    #spawn the server in a separate thread
    @httpd = Thread.new do
      Thin::Logging.silent = true
      Thin::Server.start(app) 
    end
    #give the server a chance to initialize
    sleep 0.1
  end

  after(:all) do
    # kill the server thread
    @httpd.exit
  end


end
