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

  end

  describe 'response' do
    before do
      @net_http_adapter_response = mock('net_http_adapter_response')
      Resourceful::NetHttpAdapter.stub!(:make_request).and_return(@net_http_adapter_response)

      @response = mock('response')
      Resourceful::Response.stub!(:new).and_return(@response)
    end

    it 'should be a method' do
      @request.should respond_to(:response)
    end

    it 'should look in the cache'

    it 'should create a Resourceful::Response object from the NetHttpAdapter response' do
      Resourceful::Response.should_receive(:new).with(@net_http_adapter_response).and_return(@response)
      @request.response
    end

    it 'should set the response to #response' do
      @request.response.should == @response
    end

    it 'should return the Response object' do
      @request.response.should == @response
    end

    describe 'GET' do
      before do
        @request = Resourceful::Request.new(:get, @resource)
      end

      it 'should #get the uri from the NetHttpAdapter' do
        Resourceful::NetHttpAdapter.should_receive(:make_request).
          with(:get, @uri, nil, nil).and_return(@net_http_adapter_response)
        @request.response
      end

    end

    describe 'POST' do
      before do
        @post_data = 'Hello from post!'
        @request = Resourceful::Request.new(:post, @resource, @post_data)
      end

      it 'should #get the uri from the NetHttpAdapter' do
        Resourceful::NetHttpAdapter.should_receive(:make_request).with(:post, @uri, @post_data, nil).and_return(@net_http_adapter_response)
        @request.response
      end

    end

  end

  describe '#should_be_redirected?' do
    before do
      @net_http_adapter_response = mock('net_http_adapter_response')
      Resourceful::NetHttpAdapter.stub!(:make_request).and_return(@net_http_adapter_response)

      @response = mock('response')
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

end

