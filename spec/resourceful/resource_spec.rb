require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/resource'

describe Resourceful::Resource do
  before do
    @auth_manager = mock('auth_manager', :add_credentials => nil)
    @cache_manager = mock('cache_manager', :lookup => nil, :store => nil, :invalidate => nil)
    @logger = mock('logger', :debug => nil, :info => nil)
    @accessor = mock('accessor', :auth_manager => @auth_manager, 
                                 :cache_manager => @cache_manager, 
                                 :logger => @logger)

    @uri      = 'http://www.example.com/'
    @resource = Resourceful::Resource.new(@accessor, @uri)

    @response = mock('response', :code => 200, 
                                 :is_redirect? => false, 
                                 :is_not_authorized? => false, 
                                 :is_success? => true,
                                 :is_not_modified? => false)

    @request = mock('request', :response => @response, :should_be_redirected? => true, :uri => @uri, :header => Resourceful::Header.new({}), :max_age => nil)
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

    it 'should take some default_options' do
      r = Resourceful::Resource.new(@accessor, @uri, :foo => :bar)
      r.default_options.should == {:foo => :bar}
    end

    it 'should default to an empty hash for options' do
      @resource.default_options.should == {}
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

  describe '#do_read_request' do

    def make_request
      @resource.do_read_request(:some_method)
    end

    it 'should make a new request object from the method' do
      Resourceful::Request.should_receive(:new).with(:some_method, @resource, nil, {}).and_return(@request)
      make_request
    end

    it 'should set the header of the request from the header arg' do
      Resourceful::Request.should_receive(:new).with(:some_method, @resource, nil, :foo => :bar).and_return(@request)
      @resource.do_read_request(:some_method, :foo => :bar)
    end

    describe 'default options' do
      before do
        @resource.default_options = {:foo => :bar}
      end

      it 'should merge the header with the default options' do
        Resourceful::Request.should_receive(:new).with(anything, anything, anything, :foo => :bar).and_return(@request)
        make_request
      end

      it 'should override any default header with the request header' do
        Resourceful::Request.should_receive(:new).with(anything, anything, anything, :foo => :baz).and_return(@request)
        @resource.do_read_request(:some_method, :foo => :baz)
      end
    end

    describe 'non-success responses' do
      before do
        @uri      = 'http://www.example.com/code/404'
        @resource = Resourceful::Resource.new(@accessor, @uri)

        @redirected_uri = 'http://www.example.com/get'
        @redirect_response = mock('redirect_response',
                                  :header                 => {'Location' => [@redirected_uri]},
                                  :is_redirect?           => false,
                                  :is_success?            => false,
                                  :is_not_authorized?     => false,
                                  :is_not_modified?       => false,
                                  :code                   => 404)
        
        @request.stub!(:response).and_return(@redirect_response, @response)
        @request.stub!(:method).and_return(:get)
        @request.stub!(:uri).and_return('http://www.example.com/code/404')
      end

      it 'should raise UnsuccessfulHttpRequestError' do
        lambda {
          @resource.do_read_request(:get)
        }.should raise_error(Resourceful::UnsuccessfulHttpRequestError)
      end 

      it 'should give a reasonable error message' do
        lambda {
          @resource.do_read_request(:get)
        }.should raise_error("get request to <http://www.example.com/code/404> failed with code 404")
      end
    end 

    describe 'with redirection' do
      before do
        @uri      = 'http://www.example.com/redirect/301?http://www.example.com/get'
        @resource = Resourceful::Resource.new(@accessor, @uri)

        @redirected_uri = 'http://www.example.com/get'
        @redirect_response = mock('redirect_response',
                                  :header                 => {'Location' => [@redirected_uri]},
                                  :is_redirect?           => true,
                                  :is_permanent_redirect? => true,
                                  :is_not_modified?       => false)

        @request.stub!(:response).and_return(@redirect_response, @response)

      end

      it 'should check if the response was a redirect' do
        @redirect_response.should_receive(:is_redirect?).and_return(true)
        make_request
      end

      it 'should check if the request should be redirected' do
        @request.should_receive(:should_be_redirected?).and_return(true)
        make_request
      end

      describe 'permanent redirect' do
        before do
          @redirect_response.stub!(:is_permanent_redirect?).and_return(true)
        end

        it 'should check if the response was a permanent redirect' do
          @redirect_response.should_receive(:is_permanent_redirect?).and_return(true)
          make_request
        end

        it 'should add the new location as the effective uri' do
          make_request
          @resource.effective_uri.should == @redirected_uri
        end

        it 'should remake the request with the new uri' do
          Resourceful::Request.should_receive(:new).twice.and_return(@request)
          @request.should_receive(:response).twice.and_return(@redirect_response, @response)
          make_request
        end

      end

      describe 'temporary redirect' do
        before do
          @redirect_response.stub!(:is_permanent_redirect?).and_return(false)
        end

        it 'should check if the response was not a permanent redirect' do
          @redirect_response.should_receive(:is_permanent_redirect?).and_return(false)
          make_request
        end

        it 'should not add the new location as the effective uri' do
          make_request
          @resource.effective_uri.should == @uri
        end
        
        it 'should make a new resource from the new location' do
          new_resource = mock('resource', :do_read_request => @response, :uri => @uri)
          Resourceful::Resource.should_receive(:new).with(@accessor, @redirected_uri).and_return(new_resource)
          make_request
        end

      end

    end # read with redirection

    describe 'with authorization' do
      before do
        @authmgr = mock('auth_manager')
        @authmgr.stub!(:add_credentials)
        @authmgr.stub!(:associate_auth_info).and_return(true)

        @accessor.stub!(:auth_manager).and_return(@authmgr)
      end

      it 'should attempt to add credentials to the request' do
        @authmgr.should_receive(:add_credentials).with(@request)
        make_request
      end

      it 'should check if the response was not authorized' do
        @response.should_receive(:is_not_authorized?).and_return(false)
        make_request
      end

      it 'should associate the auth info in the response if it was not authorized' do
        @authmgr.should_receive(:associate_auth_info).with(@response).and_return(true)
        @response.stub!(:is_not_authorized?).and_return(true)
        make_request
      end

      it 'should re-make the request only once if it was not authorized the first time' do
        Resourceful::Request.should_receive(:new).with(:some_method, @resource, nil, {}).twice.and_return(@request)
        @response.stub!(:is_not_authorized?).and_return(true)
        make_request
      end

    end

    describe 'with caching' do
      before do
        @cached_response = mock('cached response', :is_redirect? => false,
                                                   :is_not_authorized? => false,
                                                   :is_success? => true,
                                                   :stale? => false)
        @cache_manager.stub!(:lookup).and_return(@cached_response)
      end

      it 'should lookup the request in the cache' do
        @cache_manager.should_receive(:lookup).with(@request)
        make_request
      end

      it 'should not lookup the request in the cache if the request has no-cache directive' do
        @request.header['Cache-Control'] = 'no-cache'
        @cache_manager.should_not_receive(:lookup).with(@request)
        make_request
      end

      it 'should check if the cached response is stale' do
        @cached_response.should_receive(:stale?).and_return(false)
        make_request
      end

      it 'should not store the response in the cache if the request has no-store directive' do
        @request.header['Cache-Control'] = 'no-store'
        @cache_manager.should_not_receive(:store).with(@request)
        make_request
      end

      describe 'in cache' do

      end

      describe 'in cache but stale' do

      end

      describe 'not in cache' do

      end

    end

  end

  describe '#do_write_request' do

    def make_request
      @resource.do_write_request(:some_method, "data")
    end

    it 'should make a new request object from the method' do
      Resourceful::Request.should_receive(:new).with(:some_method, @resource, "data", anything).and_return(@request)
      @resource.do_write_request(:some_method, "data")
    end

    describe 'default options' do
      before do
        @resource.default_options = {:foo => :bar}
      end

      it 'should merge the header with the default options' do
        Resourceful::Request.should_receive(:new).with(anything, anything, anything, :foo => :bar).and_return(@request)
        make_request
      end

      it 'should override any default header with the request header' do
        Resourceful::Request.should_receive(:new).with(anything, anything, anything, :foo => :baz).and_return(@request)
        @resource.do_write_request(:some_method, "data", :foo => :baz)
      end
    end

    describe 'non-success responses' do
      before do
        @uri      = 'http://www.example.com/code/404'
        @resource = Resourceful::Resource.new(@accessor, @uri)

        @redirected_uri = 'http://www.example.com/get'
        @response = mock('response',
                         :header                 => {'Location' => [@redirected_uri]},
                         :is_redirect?           => false,
                         :is_success?            => false,
                         :is_not_authorized?     => false,
                         :code                   => 404)
        
        @request.stub!(:response).and_return(@response)
        @request.stub!(:method).and_return(:post)
        @request.stub!(:uri).and_return('http://www.example.com/code/404')
      end

      it 'should raise UnsuccessfulHttpRequestError' do
        lambda {
          @resource.do_write_request(:post, "data")
        }.should raise_error(Resourceful::UnsuccessfulHttpRequestError)
      end 

      it 'should give a reasonable error message' do
        lambda {
          @resource.do_write_request(:post, "data")
        }.should raise_error("post request to <http://www.example.com/code/404> failed with code 404")
      end
    end 

    describe 'with redirection' do
      before do
        @uri      = 'http://www.example.com/redirect/301?http://www.example.com/get'
        @resource = Resourceful::Resource.new(@accessor, @uri)

        @redirected_uri = 'http://www.example.com/get'
        @redirect_response = mock('redirect_response',
                                  :header                 => {'Location' => [@redirected_uri]},
                                  :is_redirect?           => true,
                                  :is_permanent_redirect? => true)

        @request.stub!(:response).and_return(@redirect_response, @response)

      end

      it 'should check if the response was a redirect' do
        @redirect_response.should_receive(:is_redirect?).and_return(true)
        make_request
      end

      it 'should check if the request should be redirected' do
        @request.should_receive(:should_be_redirected?).and_return(true)
        make_request
      end

      describe 'permanent redirect' do
        before do
          @redirect_response.stub!(:is_permanent_redirect?).and_return(true)
        end

        it 'should check if the response was a permanent redirect' do
          @redirect_response.should_receive(:is_permanent_redirect?).and_return(true)
          make_request
        end

        it 'should add the new location as the effective uri' do
          make_request
          @resource.effective_uri.should == @redirected_uri
        end

        it 'should remake the request with the new uri' do
          Resourceful::Request.should_receive(:new).twice.and_return(@request)
          @request.should_receive(:response).twice.and_return(@redirect_response, @response)
          make_request
        end

      end

      describe 'temporary redirect' do
        before do
          @redirect_response.stub!(:is_permanent_redirect?).and_return(false)
            @redirect_response.stub!(:code).and_return(302)
        end

        it 'should check if the response was not a permanent redirect' do
          @redirect_response.should_receive(:is_permanent_redirect?).and_return(false)
          make_request
        end

        it 'should not add the new location as the effective uri' do
          make_request
          @resource.effective_uri.should == @uri
        end
        
        it 'should make a new resource from the new location' do
          new_resource = mock('resource', :do_write_request => @response)
          Resourceful::Resource.should_receive(:new).with(@accessor, @redirected_uri).and_return(new_resource)
          make_request
        end

        describe '302 Found' do
          before do
            @new_resource = mock('resource')
            Resourceful::Resource.should_receive(:new).with(@accessor, @redirected_uri).and_return(@new_resource)
            @redirect_response.stub!(:code).and_return(303)
          end

          it 'should redirect to the new location with a GET request, regardless of the original method' do
            @new_resource.should_receive(:do_read_request).with(:get, {}).and_return(@response)
            make_request
          end
        end

      end

    end # write with redirection
    
    describe 'with authorization' do
      before do
        @authmgr = mock('auth_manager')
        @authmgr.stub!(:add_credentials)
        @authmgr.stub!(:associate_auth_info).and_return(true)

        @accessor.stub!(:auth_manager).and_return(@authmgr)
      end

      it 'should attempt to add credentials to the request' do
        @authmgr.should_receive(:add_credentials).with(@request)
        make_request
      end

      it 'should check if the response was not authorized' do
        @response.should_receive(:is_not_authorized?).and_return(false)
        make_request
      end

      it 'should associate the auth info in the response if it was not authorized' do
        @authmgr.should_receive(:associate_auth_info).with(@response).and_return(true)
        @response.stub!(:is_not_authorized?).and_return(true)
        make_request
      end

      it 'should re-make the request only once if it was not authorized the first time' do
        Resourceful::Request.should_receive(:new).with(:some_method, @resource, "data", {}).twice.and_return(@request)
        @response.stub!(:is_not_authorized?).and_return(true)
        make_request
      end
    end

  end

  describe 'callback registration' do
    before do
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
      callback = lambda { "foo" }
      @resource.on_redirect(&callback)
      @resource.on_redirect.should == callback
    end

  end

  describe '#get' do

    it 'should be a method' do
      @resource.should respond_to(:get)
    end

    it 'should pass :get to the #do_read_request method' do
      @resource.should_receive(:do_read_request).with(:get, {}).and_return(@response)
      @resource.get
    end

    it 'should return the response of making the request' do
      @resource.get.should == @response
    end

  end

  describe "#delete" do

    it 'should be a method' do
      @resource.should respond_to(:delete)
    end

    it 'should return the response of making the request' do
      @resource.delete.should == @response
    end

  end

  describe "#post(body_data, :content_type => content-type)" do
    before do
      @resource = Resourceful::Resource.new(@accessor, 'http://foo.invalid/')
      @response = mock('response', :is_redirect? => false, :is_success? => true, :is_not_authorized? => false, :code => 200)
      @request = mock('request', :response => @response)
      Resourceful::Request.stub!(:new).and_return(@request)
    end
    
    it "should get the response from the request" do 
      @request.should_receive(:response).and_return(@response)

      @resource.post("a body", :content_type => 'text/plain')
    end

    it 'should put the content type in the header' do
      Resourceful::Request.should_receive(:new).
        with(anything,
             anything, 
             anything, 
             hash_including(:content_type =>'text/plain')).
        and_return(@request)

      @resource.post("a body", :content_type => 'text/plain') 
    end 

    it 'should create a post request' do
      Resourceful::Request.should_receive(:new).
        with(:post, anything, anything, anything).
        and_return(@request)

      @resource.post("a body", :content_type => 'text/plain') 
    end 

    it 'should pass body to the request object' do
      Resourceful::Request.should_receive(:new).
        with(anything, anything, "a body", anything).
        and_return(@request)

      @resource.post("a body", :content_type => 'text/plain') 
    end 

    it 'should pass self to the request object' do
      Resourceful::Request.should_receive(:new).
        with(anything, @resource, anything, anything).
        and_return(@request)

      @resource.post("a body", :content_type => 'text/plain') 
    end 
  end

  describe "#put(body_data, :content_type => content_type)" do
    before do
      @resource = Resourceful::Resource.new(@accessor, 'http://foo.invalid/')
      @response = mock('response', :is_redirect? => false, :is_success? => true, :is_not_authorized? => false, :code => 200)
      @request = mock('request', :response => @response)
      Resourceful::Request.stub!(:new).and_return(@request)
    end
    
    it "should get the response from the request" do 
      @request.should_receive(:response).and_return(@response)

      @resource.put("a body", :content_type => 'text/plain')
    end

    it 'should put the content type in the header' do
      Resourceful::Request.should_receive(:new).
        with(anything,
             anything, 
             anything, 
             hash_including(:content_type =>'text/plain')).
        and_return(@request)

      @resource.put("a body", :content_type => 'text/plain') 
    end 

    it 'should create a put request' do
      Resourceful::Request.should_receive(:new).
        with(:put, anything, anything, anything).
        and_return(@request)

      @resource.put("a body", :content_type => 'text/plain') 
    end 

    it 'should pass body to the request object' do
      Resourceful::Request.should_receive(:new).
        with(anything, anything, "a body", anything).
        and_return(@request)

      @resource.put("a body", :content_type => 'text/plain') 
    end 

    it 'should pass self to the request object' do
      Resourceful::Request.should_receive(:new).
        with(anything, @resource, anything, anything).
        and_return(@request)

      @resource.put("a body", :content_type => 'text/plain') 
    end 
  end

end 
