require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/resource'

describe Resourceful::Resource do
  before do
    @accessor = mock('http_accessor')
    @uri      = 'http://www.example.com/'
    @resource = Resourceful::Resource.new(@accessor, @uri)

    @response = mock('response', :code => 200, :is_redirect? => false)

    @request = mock('request', :response => @response, :should_be_redirected? => true)
    Resourceful::Request.stub!(:new).and_return(@request)
  end

  describe 'init' do
    it 'should be instantiatable' do
      @resource.should be_instance_of(Resourceful::Resource)
    end

    it 'should take an http_accessor' do
      @resource.accessor.should == @accessor
    end

    it 'should take a uri' do
      @resource.uri.should == @uri
    end
  end

  describe '#effective_uri' do

    it 'should be the latest uri' do
      @resource.effective_uri.should == @uri
    end

    it 'should be aliased as #uri' do
      @resource.uri.should == @resource.effective_uri
    end

  end

  describe '#get' do

    it 'should be a method' do
      @resource.should respond_to(:get)
    end

    it 'should create a request object with GET method and itself' do
      Resourceful::Request.should_receive(:new).with(:get, @resource).and_return(@request)
      @resource.get
    end

    it 'should make the request' do
      @request.should_receive(:response).and_return(@response)
      @resource.get
    end

    it 'should return the response of making the request' do
      @resource.get.should == @response
    end

  end

  describe '#post' do

    it 'should be a method' do
      @resource.should respond_to(:post)
    end
    
    it 'should create a request object with POST method, itself, and the body' do
      Resourceful::Request.should_receive(:new).with(:post, @resource, 'Hello from post!').and_return(@request)
      @resource.post('Hello from post!')
    end

    it 'should make the request' do
      @request.should_receive(:response).and_return(@response)
      @resource.post('Hello from post!')
    end

    it 'should return the response of making the request' do
      @resource.post('Hello from post!').should == @response
    end

  end

  describe '#put' do

    it 'should be a method' do
      @resource.should respond_to(:put)
    end
    
    it 'should create a request object with POST method, itself, and the body' do
      Resourceful::Request.should_receive(:new).with(:put, @resource, 'Hello from put!').and_return(@request)
      @resource.put('Hello from put!')
    end

    it 'should make the request' do
      @request.should_receive(:response).and_return(@response)
      @resource.put('Hello from put!')
    end

    it 'should return the response of making the request' do
      @resource.put('Hello from put!').should == @response
    end

  end

  describe '#delete' do

    it 'should be a method' do
      @resource.should respond_to(:delete)
    end
    
    it 'should create a request object with POST method, itself, and the body' do
      Resourceful::Request.should_receive(:new).with(:delete, @resource).and_return(@request)
      @resource.delete
    end

    it 'should make the request' do
      @request.should_receive(:response).and_return(@response)
      @resource.delete
    end

    it 'should return the response of making the request' do
      @resource.delete.should == @response
    end

  end

  describe 'redirect' do

    describe 'callback registration' do
      before do
        @uri      = 'http://www.example.com/redirect/301?http://www.example.com/get'
        @resource = Resourceful::Resource.new(@accessor, @uri)

        @redirected_uri = 'http://www.example.com/get'
        @redirect_response = mock('redirect_response', :code => 301, :header => {'Location' => [@redirected_uri]}, :is_redirect? => true)
        @request.stub!(:response).and_return(@redirect_response, @response)

        @callback = mock('callback')
        @callback.stub!(:call).and_return(true)

        @resource.on_redirect { @callback.call }
      end

      it 'should store the callback when called with a block' do
        @resource.on_redirect { true }

        callback = @resource.instance_variable_get(:@on_redirect)
        callback.should be_kind_of(Proc)
      end

      it 'should return the callback when called without a block' do
        @resource.on_redirect { true }
        @resource.on_redirect.should be_kind_of(Proc)
      end

      it 'should yield the request,response to the callback' do
        @resource.on_redirect { |req,resp|
          req.should == @request
          resp.should == @redirect_response
        }

        @resource.get
      end

    end

    describe '301 Moved Permanently' do
      before do
        @uri      = 'http://www.example.com/redirect/301?http://www.example.com/get'
        @resource = Resourceful::Resource.new(@accessor, @uri)

        @redirected_uri = 'http://www.example.com/get'
        @redirect_response = mock('redirect_response', :code => 301, :header => {'Location' => [@redirected_uri]}, :is_redirect? => true)
        @request.stub!(:response).and_return(@redirect_response, @response)

        @callback = mock('callback')
        @callback.stub!(:call).and_return(true)
      end

      it 'should be followed automatically on GET' do
        @request.should_receive(:response).and_return(@redirect_response, @response)
        @resource.get.should == @response
      end

      it 'should add the redirected to uri to the beginning of the uri list' do
        @resource.instance_variable_get(:@uris).should == [@uri]
        @resource.get
        @resource.instance_variable_get(:@uris).should == ['http://www.example.com/get', @uri]
      end

      it 'should have the redirected to uri as the effective uri' do
        @resource.get
        @resource.effective_uri.should == @redirected_uri
      end

      %w{PUT POST DELETE}.each do |method|
        it "should not redirect automatically on #{method}" do
          @request.should_receive(:response).once.and_return(@redirect_response)
          @resource.send(method.downcase.intern).should == @redirect_response
        end

        it "should redirect on #{method} if the redirection callback returns true" do
          @resource.on_redirect { @callback.call }
          @resource.send(method.downcase.intern).should == @response
        end

        it "should not redirect on #{method} if the redirection callback returns false" do
          @callback.stub!(:call).and_return(false)
          @resource.on_redirect { @callback.call }
          @request.stub!(:response).once.and_return(@redirect_response)
          @resource.send(method.downcase.intern).should == @redirect_response
        end
      end

    end

    describe '302 Found' do
      before do
        @uri      = 'http://www.example.com/redirect/302?http://www.example.com/get'
        @resource = Resourceful::Resource.new(@accessor, @uri)

        @redirected_uri = 'http://www.example.com/get'
        @redirect_response = mock('redirect_response', :code => 302, :header => {'Location' => [@redirected_uri]}, :is_redirect? => true)
        @request.stub!(:response).and_return(@redirect_response, @response)

        @callback = mock('callback')
        @callback.stub!(:call).and_return(true)
      end

      it 'should be followed automatically on GET' do
        @request.should_receive(:response).and_return(@redirect_response, @response)
        @resource.get.should == @response
      end

      it 'should not add the redirected to uri to the beginning of the uri list' do
        @resource.instance_variable_get(:@uris).should == [@uri]
        @resource.get
        @resource.instance_variable_get(:@uris).should == [@uri]
      end

      it 'should have the original request uri as the effective uri' do
        @resource.get
        @resource.effective_uri.should == @uri
      end

      %w{PUT POST DELETE}.each do |method|
        it "should not redirect automatically on #{method}" do
          @request.should_receive(:response).once.and_return(@redirect_response)
          @resource.send(method.downcase.intern).should == @redirect_response
        end

        it "should redirect on #{method} if the redirection callback returns true" do
          @resource.on_redirect { @callback.call }
          @resource.send(method.downcase.intern).should == @response
        end

        it "should not redirect on #{method} if the redirection callback returns false" do
          @callback.stub!(:call).and_return(false)
          @resource.on_redirect { @callback.call }
          @request.stub!(:response).once.and_return(@redirect_response)
          @resource.send(method.downcase.intern).should == @redirect_response
        end
      end

    end

    describe '303 See Other' do

    end

    describe '307 Temporary Redirect' do

    end
    
  end

end

