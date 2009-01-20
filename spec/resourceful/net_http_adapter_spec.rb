require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/net_http_adapter'

describe Resourceful::NetHttpAdapter do
  describe '#make_request (mocked)' do
    it 'should enable ssl on the connection' do
      resp = stub('http_response', :code => 200, :header => {}, :body => "hello")
      conn = stub('http_conn', :request => resp, :finish => nil)
      Net::HTTP.should_receive(:new).and_return(conn)
      conn.should_receive(:use_ssl=).with(true).ordered
      conn.should_receive(:start).ordered

      Resourceful::NetHttpAdapter.make_request(:get, 'https://localhost:3000/get')
    end
  end
end

describe Resourceful::NetHttpAdapter do

  describe '#make_request' do
    before do
      @response = Resourceful::NetHttpAdapter.make_request(:get, 'http://localhost:3000/get')
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

  describe '#net_http_request_class' do

    it 'should provide Net::HTTP::Get for a get method' do
      Resourceful::NetHttpAdapter.send(:net_http_request_class, :get).should == Net::HTTP::Get
    end

    it 'should provide Net::HTTP::Post for a post method' do
      Resourceful::NetHttpAdapter.send(:net_http_request_class, :post).should == Net::HTTP::Post
    end

    it 'should provide Net::HTTP::Put for a put method' do
      Resourceful::NetHttpAdapter.send(:net_http_request_class, :put).should == Net::HTTP::Put
    end

    it 'should provide Net::HTTP::Delete for a delete method' do
      Resourceful::NetHttpAdapter.send(:net_http_request_class, :delete).should == Net::HTTP::Delete
    end

  end

  describe "#proxy_details" do
    it 'should return nil when http_proxy environment variable not set' do
      ENV.should_receive(:[]).with('http_proxy').and_return(nil)
      Resourceful::NetHttpAdapter.send(:proxy_details).should be_nil
    end

    it 'should return a 4 element Array when http_proxy environment variable is set' do
      ENV.should_receive(:[]).with('http_proxy').and_return("http://user:password@example.com:4321")
      Resourceful::NetHttpAdapter.send(:proxy_details).should == ["example.com", 4321, "user", "password"]
    end
  end

end

describe Addressable::URI, '#absolute_path monkey patch' do

  it 'should have the path and any query parameters' do
    uri = Addressable::URI.parse('http://localhost/foo?bar=baz')
    uri.absolute_path.should == '/foo?bar=baz'
  end

  it 'should not have a ? if there are no query params' do
    uri = Addressable::URI.parse('http://localhost/foo')
    uri.absolute_path.should_not =~ /\?/
    uri.absolute_path.should == '/foo'
  end

  it 'should not add the query parameter twice' do
    uri = Addressable::URI.parse('http://localhost/foo?bar=baz')
    uri.absolute_path.should == '/foo?bar=baz'
    uri.absolute_path.should == '/foo?bar=baz'
  end

end
