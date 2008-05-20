require 'pathname'
require Pathname(__FILE__).dirname + 'spec_helper'
require Pathname(__FILE__).dirname + 'acceptance_shared_specs'

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

    describe 'redirecting' do

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

      describe 'permanent redirect' do
        before do
          @redirect_code = 301
          @resource = @accessor.resource('http://localhost:3000/redirect/301?http://localhost:3000/get')
        end

        it_should_behave_like 'redirect'

        it 'should change the effective uri of the resource' do
          @resource.get
          @resource.effective_uri.should == 'http://localhost:3000/get'
        end
      end

      describe 'temporary redirect' do
        before do
          @redirect_code = 302
          @resource = @accessor.resource('http://localhost:3000/redirect/302?http://localhost:3000/get')
        end

        it_should_behave_like 'redirect'

        it 'should not change the effective uri of the resource' do
          @resource.get
          @resource.effective_uri.should == 'http://localhost:3000/redirect/302?http://localhost:3000/get'
        end

        describe '303 See Other' do
          before do
            @redirect_code = 303
            @resource = @accessor.resource('http://localhost:3000/redirect/303?http://localhost:3000/method')
            @resource.on_redirect { true }
          end

          it 'should GET the redirected resource, regardless of the initial method' do
            resp = @resource.delete
            resp.code.should == 200
            resp.body.should == 'GET'
          end
        end
      end

    end

    describe 'caching' do
      before do
        @accessor = Resourceful::HttpAccessor.new(:cache_manager => Resourceful::InMemoryCacheManager.new)
      end

      it 'should use the cached response' do
        resource = @accessor.resource('http://localhost:3000/get')
        resp = resource.get
        puts resp.inspect
        resp.authoritative?.should be_true

        resp2 = resource.get
        puts resp2.inspect
        resp2.authoritative?.should be_false
      end
      
      it 'should store a fetched representation'

      it 'should not store the representation if the server says not to'

      it 'should use the cached version of the representation if it has not expired'

      it 'should provide the cached version if the server replies with a 304'

      it 'should track representations by uri and vary header'

    end

    describe 'error checking' do

      it 'should raise InvalidResponse when response code is invalid'

      describe 'client errors' do

        it 'should raise when there is one'

      end

      describe 'server errors' do

        it 'should raise when there is one'

      end

    end

  end

end

