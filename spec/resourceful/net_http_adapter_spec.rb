require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/net_http_adapter'

describe Resourceful::NetHttpAdapter do
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

  # this really doesn't have anything to do with the Adapter, it just makes sure the server is behaving as it should
  describe 'http server' do

    it 'should have a response code of whatever the path is' do
      Resourceful::NetHttpAdapter.get('http://localhost:3000/304')[0].should == 304
    end

    it 'should have a response code of 200 if the path isnt a code' do
      Resourceful::NetHttpAdapter.get('http://localhost:3000/index')[0].should == 200
    end
  end

  describe '#get' do
    before do
      @response = Resourceful::NetHttpAdapter.get('http://localhost:3000/index')
    end

    describe 'response' do
      it 'should be an array' do
        @response.should be_instance_of(Array)
      end

      it 'should have the numeric response code as the first element' do
        code = @response[0]
        code.should be_instance_of(Fixnum)
        code.should == 200
      end

      it 'should have the Header as the second element' do
        header = @response[1]
        header.should be_instance_of(Resourceful::Header)
        header['content-type'].should == ['text/plain']
      end

      it 'should have the body as the third and last element' do
        body = @response[2]
        body.should == "Hello, world!"
      end

    end

  end

  after(:all) do
    # kill the server thread
    @httpd.exit
  end

end

