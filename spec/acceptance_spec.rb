require 'pathname'
require Pathname(__FILE__).dirname + 'spec_helper'

require 'resourceful'

describe Resourceful do
  before(:all) do
    #setup a thin http server we can connect to
    require 'thin'

    app = proc do |env|
      resp_code = env['PATH_INFO'] =~ /([\d]+)/ ? Integer($1) : 200
      body = ["Hello, world!"]

      [ resp_code, {'Content-Type' => 'text/plain', 'Content-Length' => body.join.size.to_s}, body ]
    end

    #spawn the server in a separate thread
    @httpd = Thread.new do
      Thin::Logging.silent = true
      Thin::Server.start(app) 
    end
    #give the server a chance to initialize
    sleep 0.1
    
  end

  describe 'http server' do
    it 'should have a response code of whatever the path is' do
      Resourceful::NetHttpAdapter.get('http://localhost:3000/304')[0].should == 304
    end

    it 'should have a response code of 200 if the path isnt a code' do
      Resourceful::NetHttpAdapter.get('http://localhost:3000/index')[0].should == 200
    end
  end

  describe 'getting a resource' do
    before do
      @accessor = Resourceful::HttpAccessor.new
      @resource = @accessor.resource('http://localhost:3000/index')
    end

    it 'should #get a resource, and return a response object' do
      resp = @resource.get
      resp.should be_instance_of(Resourceful::Response)
      resp.code.should == 200
      resp.body.should == 'Hello, world!'
      resp.header.should be_instance_of(Resourceful::Header)
      resp.header['Content-Type'].should == ['text/plain']
    end

    it 'should explode when response code is invalid'

  end

  after(:all) do
    # kill the server thread
    @httpd.exit
  end

end
