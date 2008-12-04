require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/memcache_cache_manager'
require 'resourceful/request'

describe Resourceful::MemcacheCacheManager do
  before do
    @resource = stub('resource', :uri => 'http://foo.invalid/')

    @request = Resourceful::Request.new(:get, @resource)
    @response = Resourceful::Response.new('http://foo.invalid/', '200', {'Vary' => 'Accept'}, "a body")
    
    @memcache = stub('memcache', :get => nil)
    MemCache.stub!(:new).and_return(@memcache)

    @cache_mngr = Resourceful::MemcacheCacheManager.new('foobar:42')
  end

  describe "#store(request,response)" do
    it "should store the new pair in memcache" do
      @memcache.should_receive(:[]=).with do |key, collection|
        key.should == Digest::MD5.hexdigest('http://foo.invalid/')
        collection[@request].should == @response
      end

      @cache_mngr.store(@request, @response)
    end 
  
    it "should replace existing values if they exist" do
      entries = Resourceful::CacheEntryCollection.new
      entries[@request] = @response
      @memcache.stub!(:[]=).and_return(entries)

      new_request = Resourceful::Request.new(:get, @resource)
      new_response = Resourceful::Response.new('http://foo.invalid/', '200', {}, "a different body")

      @memcache.should_receive(:[]=).with do |key, collection|
        collection[new_request].should == new_response
      end
      
      @cache_mngr.store(new_request, new_response)
    end 

    it "should not store responses that are not cacheable" do
      @memcache.should_not_receive(:[]=)

      vary_star_response = Resourceful::Response.new('http://foo.invalid/', '200', {'Vary' => '*'}, "a different body")
 
      @cache_mngr.store(@request, vary_star_response)     
    end 
  end 

  describe "#lookup" do
    before do
      @entries = Resourceful::CacheEntryCollection.new
      @entries[@request] = @response
      @memcache.stub!(:get).and_return(@entries)
    end
    
    it "should lookup the entry collection by the URI" do
      @memcache.should_receive(:get).with(Digest::MD5.hexdigest('http://foo.invalid/')).and_return(@entries)

      @cache_mngr.lookup(@request)
    end
 
    it "should retrieve responses that match request" do
      @cache_mngr.lookup(Resourceful::Request.new(:get, @resource)).should == @response
    end 

    it "should return nil if no responses that match request are found" do
      @cache_mngr.lookup(Resourceful::Request.new(:get, @resource, "body", {'Accept' => 'text/plain'})).
        should be_nil
    end 

    it "should return nil if no responses that resource are found" do
      @memcache.stub!(:get).and_return(nil)

      @cache_mngr.lookup(Resourceful::Request.new(:get, @resource)).should be_nil
    end 
  end 

  describe "#invalidate(url)" do
    it "should remove all cached responses for that resource from memcache" do
      @memcache.should_receive(:delete).with(Digest::MD5.hexdigest('http://foo.invalid/'))

      @cache_mngr.invalidate('http://foo.invalid/')
    end 
  end 
end 

describe Resourceful::MemcacheCacheManager, 'init' do 
  it 'should be createable with single memcache server' do
    MemCache.should_receive(:new).with(['foobar:42'], anything)
    
    Resourceful::MemcacheCacheManager.new('foobar:42')
  end 

  it 'should be createable with multiple memcache servers' do
    MemCache.should_receive(:new).with(['foobar:42', 'baz:32'], anything)
    
    Resourceful::MemcacheCacheManager.new('foobar:42', 'baz:32')
  end 

  it 'should create a thread safe memcache client' do
    MemCache.should_receive(:new).with(anything, {:multithread => true})
    
    Resourceful::MemcacheCacheManager.new('foobar:42')
  end 
end

