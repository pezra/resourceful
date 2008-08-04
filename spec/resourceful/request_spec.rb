require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'
require 'rubygems'
require 'addressable/uri'

describe Resourceful::Request do
  before do
    @uri = Addressable::URI.parse('http://www.example.com')
    @resource = mock('resource', :logger => Resourceful::BitBucketLogger.new)
    @resource.stub!(:uri).and_return(@uri)

    @request = Resourceful::Request.new(:get, @resource)

    @cachemgr = mock('cache_mgr')
    @cachemgr.stub!(:lookup).and_return(nil)
    @cachemgr.stub!(:store)
    @resource.stub!(:accessor).and_return(mock('accessor', :cache_manager => @cachemgr, :logger => Resourceful::BitBucketLogger.new))
  end

  describe 'init' do

    it 'should be instantiatable' do
      @request.should be_instance_of(Resourceful::Request)
    end

    it 'should take an http method' do
      @request.method.should == :get
    end

    it 'should take a resource' do
      @request.resource.should == @resource
    end

    it 'should take an optional body' do
      req = Resourceful::Request.new(:get, @resource)
      req.body.should be_nil

      req = Resourceful::Request.new(:post, @resource, 'Hello from post!')
      req.body.should == 'Hello from post!'
    end

    it 'should have a request_time' do
      @request.should respond_to(:request_time)
    end

  end

  describe '#response' do
    before do
      @net_http_adapter_response = mock('net_http_adapter_response')
      Resourceful::NetHttpAdapter.stub!(:make_request).and_return(@net_http_adapter_response)

      @response = mock('response', :code => 200, :authoritative= => true, :was_unsuccessful? => false, :request_time= => nil)
      Resourceful::Response.stub!(:new).and_return(@response)
    end

    it 'should be a method' do
      @request.should respond_to(:response)
    end

    it 'should return the Response object' do
      @request.response.should == @response
    end

    it 'should set the request_time to now' do
      now = Time.now
      Time.stub!(:now).and_return(now)

      @request.response
      @request.request_time.should == now
    end

    it 'should set the response\'s request time' do
      now = Time.now
      Time.stub!(:now).and_return(now)

      @response.should_receive(:request_time=).with(now)
      @request.response
    end
  end

  describe '#should_be_redirected?' do
    before do
      @net_http_adapter_response = mock('net_http_adapter_response')
      Resourceful::NetHttpAdapter.stub!(:make_request).and_return(@net_http_adapter_response)

      @response = mock('response', :code => 200, :authoritative= => true, :was_unsuccessful? => false, :request_time= => nil)
      Resourceful::Response.stub!(:new).and_return(@response)
    end

    describe 'with no callback set' do
      before do
        @callback = nil
        @resource.stub!(:on_redirect).and_return(@callback)
      end

      it 'should be true for GET' do
        request = Resourceful::Request.new(:get, @resource, @post_data)

        request.should_be_redirected?.should be_true
      end

      it 'should be false for POST, etc' do
        request = Resourceful::Request.new(:post, @resource, @post_data)

        request.should_be_redirected?.should be_false
      end

    end

    it 'should be true when callback returns true' do
      @callback = lambda { true }
      @resource.stub!(:on_redirect).and_return(@callback)
      request = Resourceful::Request.new(:get, @resource, @post_data)

      request.should_be_redirected?.should be_true
    end

    it 'should be false when callback returns false' do
      @callback = lambda { false }
      @resource.stub!(:on_redirect).and_return(@callback)
      request = Resourceful::Request.new(:get, @resource, @post_data)

      request.should_be_redirected?.should be_false
    end

  end 

  describe "content coding" do 
    it "should set Accept-Encoding automatically" do
      @request.header['Accept-Encoding'].should == 'gzip, identity'
    end
  end

  describe '#set_validation_headers' do
    before do
      @cached_response = mock('cached_response')

      @cached_response_header = mock('header', :[] => nil, :has_key? => false)
      @cached_response.stub!(:header).and_return(@cached_response_header)

      @cachemgr.stub!(:lookup).and_return(@cached_response)
    end

    it 'should have an #set_validation_headers method' do
      @request.should respond_to(:set_validation_headers)
    end

    it 'should set If-None-Match to the cached response\'s ETag' do
      @cached_response_header.should_receive(:[]).with('ETag').and_return('some etag')
      @cached_response_header.should_receive(:has_key?).with('ETag').and_return(true)
      @request.set_validation_headers(@cached_response)

      @request.header['If-None-Match'].should == 'some etag'
    end

    it 'should not set If-None-Match if the cached response does not have an ETag' do
      @request.set_validation_headers(@cached_response)
      @request.header.should_not have_key('If-None-Match')
    end

    it 'should set If-Modified-Since to the cached response\'s Last-Modified' do
      @cached_response_header.should_receive(:[]).with('Last-Modified').and_return('some date')
      @cached_response_header.should_receive(:has_key?).with('Last-Modified').and_return(true)
      @request.set_validation_headers(@cached_response)

      @request.header['If-Modified-Since'].should == 'some date'
    end

    it 'should not set If-Modified-Since if the cached response does not have Last-Modified' do
      @request.set_validation_headers(@cached_response)
      @request.header.should_not have_key('If-Modified-Since')
    end

    it 'should add "Cache-Control: max-age=0" to the request when revalidating a response that has "Cache-Control: must-revalidate" set' do
      @cached_response_header.should_receive(:[]).with('Cache-Control').and_return(['must-revalidate'])
      @cached_response_header.should_receive(:has_key?).with('Cache-Control').and_return(true)
      @request.set_validation_headers(@cached_response)

      @request.header['Cache-Control'].should include('max-age=0')
    end

  end

end

