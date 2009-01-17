require 'pathname'
require Pathname(__FILE__).dirname + 'spec_helper'
require 'resourceful'

require Pathname(__FILE__).dirname + 'acceptance_shared_specs'


describe Resourceful do
  it_should_behave_like 'simple http server'

  describe 'working with a resource' do
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

    it 'should set additional headers on the #get' do
      resource = @accessor.resource('http://localhost:3000/echo_header')
      resp = resource.get(:foo => :bar)
      resp.should be_instance_of(Resourceful::Response)
      resp.code.should == 200
      resp.body.should =~ /"HTTP_FOO"=>"bar"/
    end

    it 'should #post a resource, and return the response' do
      resource = @accessor.resource('http://localhost:3000/post')
      resp = resource.post('Hello world from POST', :content_type => 'text/plain')
      resp.should be_instance_of(Resourceful::Response)
      resp.code.should == 201
      resp.body.should == 'Hello world from POST'
      resp.header.should be_instance_of(Resourceful::Header)
      resp.header['Content-Type'].should == ['text/plain']
    end

    it 'should #put a resource, and return the response' do
      resource = @accessor.resource('http://localhost:3000/put')
      resp = resource.put('Hello world from PUT', :content_type => 'text/plain')
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

    it 'should take an optional default header for reads' do
      resource = @accessor.resource('http://localhost:3000/echo_header', :foo => :bar)
      resp = resource.get
      resp.should be_instance_of(Resourceful::Response)
      resp.code.should == 200
      resp.body.should =~ /"HTTP_FOO"=>"bar"/
    end

    it 'should take an optional default header for writes' do
      resource = @accessor.resource('http://localhost:3000/echo_header', :foo => :bar)
      resp = resource.post("data", :content_type => 'text/plain')
      resp.should be_instance_of(Resourceful::Response)
      resp.code.should == 200
      resp.body.should =~ /"HTTP_FOO"=>"bar"/
    end

    it 'should override the default header with any set on a read action' do
      resource = @accessor.resource('http://localhost:3000/echo_header', :foo => :bar)
      resp = resource.get(:foo => :baz)
      resp.should be_instance_of(Resourceful::Response)
      resp.code.should == 200
      resp.body.should =~ /"HTTP_FOO"=>"baz"/
    end

    it 'should override the default header with any set on a write action' do
      resource = @accessor.resource('http://localhost:3000/echo_header', :foo => :bar)
      resp = resource.post("data", :foo => :baz, :content_type => 'text/plain')
      resp.should be_instance_of(Resourceful::Response)
      resp.code.should == 200
      resp.body.should =~ /"HTTP_FOO"=>"baz"/
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
          lambda {
            @resource.get
          }.should raise_error(Resourceful::UnsuccessfulHttpRequestError)
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
        resp.authoritative?.should be_true

        resp2 = resource.get
        resp2.authoritative?.should be_false

        resp2.should == resp
      end
      
      it 'should not store the representation if the server says not to' do
        resource = @accessor.resource('http://localhost:3000/header?{Vary:%20*}')
        resp = resource.get
        resp.authoritative?.should be_true
        resp.should_not be_cachable

        resp2 = resource.get
        resp2.should_not == resp
      end

      it 'should use the cached version of the representation if it has not expired' do
        in_an_hour = (Time.now + (60*60)).httpdate
        uri = URI.escape("http://localhost:3000/header?{Expire: \"#{in_an_hour}\"}")

        resource = @accessor.resource(uri)
        resp = resource.get
        resp.should be_authoritative

        resp2 = resource.get
        resp2.should_not be_authoritative
        resp2.should == resp
      end

      it 'should revalidate the cached response if it has expired' do
        an_hour_ago = (Time.now - (60*60)).httpdate
        uri = URI.escape("http://localhost:3000/header?{Expire: \"#{an_hour_ago}\"}")

        resource = @accessor.resource(uri)
        resp = resource.get
        resp.should be_authoritative
        resp.should be_expired

        resp2 = resource.get
        resp2.should be_authoritative
      end

      it 'should provide the cached version if the server responds with a 304 not modified' do
        in_an_hour = (Time.now + (60*60)).httpdate
        uri = URI.escape("http://localhost:3000/modified?#{in_an_hour}")

        resource = @accessor.resource(uri)
        resp = resource.get
        resp.should be_authoritative
        resp.header['Cache-Control'].should include('must-revalidate')

        resp2 = resource.get
        resp2.should be_authoritative
        resp2.should == resp
      end

      it 'should not use a cached document for a resource that has been posted to' do
        resource = @accessor.resource('http://localhost:3000/get')
        resp = resource.get
        resp.authoritative?.should be_true

        resource.post("foo", :content_type => 'text/plain')

        resp2 = resource.get
        resp2.should_not == resp
      end

      describe 'Server provided Cache-Control' do

        it 'should cache anything with "Cache-Control: public"' do
          uri = URI.escape('http://localhost:3000/header?{Cache-Control: public}')
          resource = @accessor.resource(uri)
          resp = resource.get
          resp.authoritative?.should be_true

          resp2 = resource.get
          resp2.authoritative?.should be_false

          resp2.should == resp
        end

        it 'should cache anything with "Cache-Control: private"' do
          uri = URI.escape('http://localhost:3000/header?{Cache-Control: private}')
          resource = @accessor.resource(uri)
          resp = resource.get
          resp.authoritative?.should be_true

          resp2 = resource.get
          resp2.authoritative?.should be_false

          resp2.should == resp
        end

        it 'should cache but revalidate anything with "Cache-Control: no-cache"' do
          uri = URI.escape('http://localhost:3000/header?{Cache-Control: no-cache}')
          resource = @accessor.resource(uri)
          resp = resource.get
          resp.authoritative?.should be_true

          resp2 = resource.get
          resp2.authoritative?.should be_true
        end

        it 'should revalidate anything that is older than "Cache-Control: max-age" value' do

          uri = URI.escape('http://localhost:3000/header?{Cache-Control: max-age=1, Date: "Mon, 04 Aug 2008 18:00:00 GMT"}')
          resource = @accessor.resource(uri)
          resp = resource.get
          resp.authoritative?.should be_true

          resp.expired?.should be_true

          resp2 = resource.get
          resp2.authoritative?.should be_true
        end

        it 'should cache but revalidate anything with "Cache-Control: must-revalidate"' do
          uri = URI.escape('http://localhost:3000/header?{Cache-Control: must-revalidate}')
          resource = @accessor.resource(uri)
          resp = resource.get
          resp.authoritative?.should be_true

          resp2 = resource.get
          resp2.authoritative?.should be_true
        end

        it 'should not cache anything with "Cache-Control: no-store"' do
          uri = URI.escape('http://localhost:3000/header?{Cache-Control: no-store}')
          resource = @accessor.resource(uri)
          resp = resource.get
          resp.authoritative?.should be_true

          resp2 = resource.get
          resp2.authoritative?.should be_true
        end


      end

      describe 'Client provided Cache-Control' do

        it 'should revalidate anything that is older than "Cache-Control: max-age" value' do
          a_minute_ago = (Time.now - 60).httpdate
          uri = URI.escape("http://localhost:3000/header?{Cache-Control: max-age=120, Date: \"#{a_minute_ago}\"}")
          resource = @accessor.resource(uri)
          resp = resource.get
          resp.authoritative?.should be_true

          resp.expired?.should be_false

          resp2 = resource.get({:cache_control => "max-age=1"})
          resp2.authoritative?.should be_true
        end

      end

    end

    describe 'authorization' do
      before do
        @uri = 'http://localhost:3000/auth?basic'
      end

      it 'should automatically add authorization info to the request if its available'

      it 'should not authenticate if no auth handlers are set' do
        resource = @accessor.resource(@uri)
        lambda {
          resource.get
        }.should raise_error(Resourceful::UnsuccessfulHttpRequestError)
      end

      it 'should not authenticate if no valid auth handlers are available' do
        basic_handler = Resourceful::BasicAuthenticator.new('Not Test Auth', 'admin', 'secret')
        @accessor.auth_manager.add_auth_handler(basic_handler)
        resource = @accessor.resource(@uri)
        lambda {
          resource.get
        }.should raise_error(Resourceful::UnsuccessfulHttpRequestError)
      end

      describe 'basic' do
        before do
          @uri = 'http://localhost:3000/auth?basic'
        end

        it 'should be able to authenticate basic auth' do
          basic_handler = Resourceful::BasicAuthenticator.new('Test Auth', 'admin', 'secret')
          @accessor.auth_manager.add_auth_handler(basic_handler)
          resource = @accessor.resource(@uri)
          resp = resource.get

          resp.code.should == 200
        end

        it 'should not keep trying to authenticate with incorrect credentials' do
          basic_handler = Resourceful::BasicAuthenticator.new('Test Auth', 'admin', 'well-known')
          @accessor.auth_manager.add_auth_handler(basic_handler)
          resource = @accessor.resource(@uri)

          lambda {
            resource.get
          }.should raise_error(Resourceful::UnsuccessfulHttpRequestError)
        end

      end

      describe 'digest' do
        before do
          @uri = 'http://localhost:3000/auth/digest'
        end

        it 'should be able to authenticate digest auth' do
          pending
          digest_handler = Resourceful::DigestAuthenticator.new('Test Auth', 'admin', 'secret')
          @accessor.auth_manager.add_auth_handler(digest_handler)
          resource = @accessor.resource(@uri)
          resp = resource.get

          resp.code.should == 200
        end

      end

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

