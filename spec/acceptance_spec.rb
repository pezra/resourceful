require 'pathname'
require Pathname(__FILE__).dirname + 'spec_helper'

require 'resourceful'

describe Resourceful do
  it_should_behave_like 'simple http server'

  describe 'getting a resource' do
    before do
      @accessor = Resourceful::HttpAccessor.new
    end

    it 'should #get a resource, and return a response object' do
      resource = @accessor.resource('http://localhost:3000/get')
      resp = resource.get
      resp.should be_instance_of(Resourceful::Response)
      resp.code.should == 200
      resp.body.should == 'Hello, world!'
      resp.header.should be_instance_of(Resourceful::Header)
      resp.header['Content-Type'].should == ['text/plain']
    end

    it 'should #post a resource, and return the response' do
      resource = @accessor.resource('http://localhost:3000/post')
      resp = resource.post('Hello world from POST')
      resp.should be_instance_of(Resourceful::Response)
      resp.code.should == 201
      resp.body.should == 'Hello world from POST'
      resp.header.should be_instance_of(Resourceful::Header)
      resp.header['Content-Type'].should == ['text/plain']
    end

    it 'should #put a resource, and return the response' do
      resource = @accessor.resource('http://localhost:3000/put')
      resp = resource.put('Hello world from PUT')
      resp.should be_instance_of(Resourceful::Response)
      resp.code.should == 200
      resp.body.should == 'Hello world from PUT'
      resp.header.should be_instance_of(Resourceful::Header)
      resp.header['Content-Type'].should == ['text/plain']
    end

    it 'should #delete a resource, and return a response' do
      resource = @accessor.resource('http://localhost:3000/delete')
      resp = resource.delete
      resp.should be_instance_of(Resourceful::Response)
      resp.code.should == 200
      resp.body.should == 'KABOOM!'
      resp.header.should be_instance_of(Resourceful::Header)
      resp.header['Content-Type'].should == ['text/plain']
    end

    describe 'redirects' do

      describe 'registering callback' do
        before do
          @resource = @accessor.resource('http://localhost:3000/redirect/301?http://localhost:3000/get')
          @callback = mock('callback')
          @callback.stub!(:call).and_return(true)

          @resource.on_redirect { @callback.call }
        end

        it 'should allow a callback to be registered' do
          @resource.should respond_to(:on_redirect)
        end

        it 'should perform a registered callback on redirect' do
          @callback.should_receive(:call).and_return(true)
          @resource.get
        end

        it 'should not perform the redirect if the callback returns false' do
          @callback.should_receive(:call).and_return(false)
          resp = @resource.get
          resp.code.should == 301
        end

      end

      describe '301 Moved Permanently' do
        before do
          @resource = @accessor.resource('http://localhost:3000/redirect/301?http://localhost:3000/get')

          @callback = mock('callback')
          @callback.stub!(:call).and_return(true)
        end

        it 'should be followed by default on GET' do
          resp = @resource.get
          resp.should be_instance_of(Resourceful::Response)
          resp.code.should == 200
          resp.header['Content-Type'].should == ['text/plain']
        end

        %w{PUT POST DELETE}.each do |method|
          it "should not be followed by default on #{method}" do
            resp = @resource.send(method.downcase.intern)
            resp.should be_instance_of(Resourceful::Response)
            resp.code.should == 301
          end

          it "should redirect on #{method} if the redirection callback returns true" do
            @resource.on_redirect { @callback.call }
            resp = @resource.send(method.downcase.intern)
            resp.code.should == 200
          end

          it "should not redirect on #{method} if the redirection callback returns false" do
            @callback.stub!(:call).and_return(false)
            @resource.on_redirect { @callback.call }
            resp = @resource.send(method.downcase.intern)
            resp.code.should == 301
          end
        end

        it 'should change the effective uri of the resource' do
          @resource.get
          @resource.effective_uri.should == 'http://localhost:3000/get'
        end

      end

      describe '302 Found' do

      end

    end

    describe 'caching' do
      
      it 'should store a fetched representation'

      it 'should not store the representation if the server says not to'

      it 'should use the cached version of the representation if it has not expired'

      it 'should provide the cached version if the server replies with a 304'

    end

    describe 'error checking' do

      it 'should raise InvalidResponse when response code is invalid'

    end

  end

end

