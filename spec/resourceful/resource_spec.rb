require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/resource'

describe Resourceful::Resource do
  before do
    @accessor = mock('http_accessor')
    @uri      = 'http://www.example.com/'
    @resource = Resourceful::Resource.new(@accessor, @uri)

    @response = mock('response')

    @request = mock('request', :make => @response)
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

  describe '#get' do

    it 'should be a method' do
      @resource.should respond_to(:get)
    end

    it 'should create a request object with GET method and itself' do
      Resourceful::Request.should_receive(:new).with(:get, @resource).and_return(@request)
      @resource.get
    end

    it 'should make the request' do
      @request.should_receive(:make)
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
      @request.should_receive(:make)
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
      @request.should_receive(:make)
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
      @request.should_receive(:make)
      @resource.delete
    end

    it 'should return the response of making the request' do
      @resource.delete.should == @response
    end

  end

end

