
require 'rubygems'
require 'fakeweb'

$LOAD_PATH << File.join(File.dirname(__FILE__), "..", "lib")
require 'resourceful'

describe "Caching" do

  before do
    FakeWeb.allow_net_connect = false
    FakeWeb.clean_registry

    @http = Resourceful::HttpAccessor.new(:cache_manager => Resourceful::InMemoryCacheManager.new)
    if ENV['SPEC_LOGGING']
      @http.logger = Resourceful::StdOutLogger.new
    end
  end

  describe "should cache" do

    before do
      FakeWeb.register_uri(:get, "http://example.com/cache",
                           [{:body => "Original response", :cache_control => "private,max-age=15"},
                            {:body => "Overrode cached response"}]
                          )

      @resource = @http.resource("http://example.com/cache")
    end

    it "should cache the response" do
      resp = @resource.get
      resp.body.should == "Original response"

      resp = @resource.get
      resp.body.should == "Original response"
    end

  end

  describe "updating headers" do
    before do
      FakeWeb.register_uri(:get, "http://example.com/override",
                           [{:body => "Original response", :cache_control => "private,max-age=0", :x_updateme => "foo"},
                            {:body => "Overrode cached response", :status => 304, :x_updateme => "bar"} ]
                          )

      @resource = @http.resource("http://example.com/override")
    end

    it "should update headers from the 304" do
      resp = @resource.get
      resp.headers['X-Updateme'].should == ["foo"]

      resp = @resource.get
      resp.headers['X-Updateme'].should == ["bar"]
      resp.headers['Cache-Control'].should == ["private,max-age=0"]
    end

  end

  describe "updating expiration" do
    before do
      FakeWeb.register_uri(:get, "http://example.com/timeout",
                           [{:body => "Original response", :cache_control => "private,max-age=1"},
                            {:body => "cached response",   :cache_control => "private,max-age=1"}]
                          )

      @resource = @http.resource("http://example.com/timeout")
    end

    it "should refresh the expiration timer" do
      resp = @resource.get
      resp.should_not be_stale

      sleep 2

      resp.should be_stale

      resp = @resource.get
      resp.should_not be_stale

      resp = @resource.get
    end

  end


end
