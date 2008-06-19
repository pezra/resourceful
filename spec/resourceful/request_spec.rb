require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'
require 'rubygems'
require 'addressable/uri'

require 'resourceful/request'

describe Resourceful::Request do
  before do
    @uri = Addressable::URI.parse('http://www.example.com')
    @resource = mock('resource')
    @resource.stub!(:uri).and_return(@uri)

    @request = Resourceful::Request.new(:get, @resource)

    @cachemgr = mock('cache_mgr')
    @cachemgr.stub!(:lookup).and_return(nil)
    @cachemgr.stub!(:store)
    @resource.stub!(:accessor).and_return(mock('accessor', :cache_manager => @cachemgr))
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

      @response = mock('response', :code => 200, :authoritative= => true)
      Resourceful::Response.stub!(:new).and_return(@response)
    end

    it 'should be a method' do
      @request.should respond_to(:response)
    end

    it 'should return the Response object' do
      @request.response.should == @response
    end

    it 'should set the request_time to now' do
      now = mock('now')
      Time.stub!(:now).and_return(now)

      @request.response
      @request.request_time.should == now
    end

    describe 'Caching' do
      before do
        @cached_response = mock('cached_response', :body => "", :authoritative= => true)
        @cached_response.stub!(:stale?).and_return(false)

        @cached_response_header = mock('header', :[] => nil, :has_key? => false)
        @cached_response.stub!(:header).and_return(@cached_response_header)

        @cachemgr.stub!(:lookup).and_return(@cached_response)
      end

      it 'should lookup the request in the cache' do
        @cachemgr.should_receive(:lookup).with(@request)
        @request.response
      end

      it 'should check if the cached response is stale' do
        @cached_response.should_receive(:stale?).and_return(false)
        @request.response
      end

      describe 'cached' do

        it 'should return the cached response if it was found and not stale' do
          @cached_response.stale?.should_not be_true
          @request.response.should == @cached_response
        end

      end

      describe 'cached but stale' do
        before do
          @cached_response.stub!(:stale?).and_return(true)
        end

        it 'should add the validation headers from the cached_response to it\'s header' do
          @request.should_receive(:set_validation_headers).with(@cached_response)

          @request.response
        end

        it 'should #get the uri from the NetHttpAdapter' do
          Resourceful::NetHttpAdapter.should_receive(:make_request).
            with(:get, @uri, nil, anything).and_return(@net_http_adapter_response)
          @request.response
        end

        it 'should create a Resourceful::Response object from the NetHttpAdapter response' do
          Resourceful::Response.should_receive(:new).with(@request.uri, @net_http_adapter_response).and_return(@response)
          @request.response
        end

        it 'should merge the response\'s headers with the cached response\'s if the response was a 304' do
          @response_header = mock('header')
          @response.stub!(:header).and_return(@response_header)
          @response.stub!(:code).and_return(304)
          @cached_response_header.should_receive(:merge).with(@response_header)
          @request.response
        end

        it 'should store the response in the cache manager' do
          @cachemgr.should_receive(:store).with(@request, @response)
          @request.response
        end

      end

      describe 'not cached' do
        before do
          @cachemgr.stub!(:lookup).and_return(nil)
        end

        it 'should #get the uri from the NetHttpAdapter' do
          Resourceful::NetHttpAdapter.should_receive(:make_request).
            with(:get, @uri, nil, anything).and_return(@net_http_adapter_response)
          @request.response
        end

        it 'should create a Resourceful::Response object from the NetHttpAdapter response' do
          Resourceful::Response.should_receive(:new).with(@request.uri, @net_http_adapter_response).and_return(@response)
          @request.response
        end

        it 'should store the response in the cache manager' do
          @cachemgr.should_receive(:store).with(@request, @response)
          @request.response
        end

      end

      describe '#set_validation_headers' do
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

  end

  describe '#should_be_redirected?' do
    before do
      @net_http_adapter_response = mock('net_http_adapter_response')
      Resourceful::NetHttpAdapter.stub!(:make_request).and_return(@net_http_adapter_response)

      @response = mock('response', :code => 200, :authoritative= => true)
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
      @request.header['Accept-Encoding'].should == 'gzip'
    end
  end

end

