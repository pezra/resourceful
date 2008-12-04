require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/cache_manager'
 
describe Resourceful::AbstractCacheManager do
  before do
    @cm = Resourceful::InMemoryCacheManager.new #cheat, because I cant new a real one. 
  end

  it 'should not be initializable' do
    lambda { Resourceful::CacheManager.new }.should raise_error
  end

  it 'should have a lookup method' do
    @cm.should respond_to(:lookup)
  end

  it 'should have a store method' do
    @cm.should respond_to(:store)
  end
  
  it 'should have a invalidate method' do
    @cm.should respond_to(:invalidate)
  end
end

describe Resourceful::NullCacheManager do
  before do
    @ncm = Resourceful::NullCacheManager.new
  end

  it 'should not find anything' do
    @ncm.lookup(:stuff).should be_nil
  end

  it 'should not store anything' do
    @ncm.should respond_to(:store)

    lambda { @ncm.store(:foo, :bar) }.should_not raise_error
  end

end

describe Resourceful::InMemoryCacheManager do
  before do
    @request = mock('request', :resource => mock('resource'),
                               :request_time => Time.utc(2008,5,22,15,00),
                               :uri => 'uri')
    @response = mock('response', :header => {}, :cachable? => true)

    @entry = mock('cache entry', :response => @response, :valid_for? => true)
    Resourceful::CacheEntry.stub!(:new).and_return(@entry)

    @imcm = Resourceful::InMemoryCacheManager.new
  end

  describe 'finding' do
    before do
      @response.stub!(:authoritative=)
      @imcm.instance_variable_set("@collection", {'uri' => {@request => @response}})
    end

    it 'should lookup the response by request' do
      @imcm.lookup(@request).should == @response
    end

    it 'should set the response to non-authoritative' do
      @response.should_receive(:authoritative=).with(false)
      @imcm.lookup(@request)
    end
  end

  describe 'saving' do
    it 'should make a new cache entry' do
      Resourceful::CacheEntry.should_receive(:new).with(
        @request,
        @response
      )

      @imcm.store(@request, @response)
    end

    it 'should store the response entity by request' do
      @imcm.store(@request, @response)
      col = @imcm.instance_variable_get("@collection")
      col['uri'][@request].should == @response
    end

    it 'should check if the response is cachable' do
      @response.should_receive(:cachable?).and_return(true)
      @imcm.store(@request, @response)
    end

    it 'should not store an entry if the response is not cachable' do
      @response.should_receive(:cachable?).and_return(false)
      @imcm.store(@request, @response)
      col = @imcm.instance_variable_get("@collection")
      col['uri'][@request].should be_nil
    end
  end

  describe 'invalidating' do
    it 'should remove an entry from the cache by uri' do
      @imcm.store(@request, @response)
      @imcm.invalidate('uri')
      col = @imcm.instance_variable_get("@collection")
      col.should_not have_key('uri')
    end
  end

end

describe Resourceful::CacheEntryCollection do
  before do
    @request = mock('request', :uri => 'this', :request_time => Time.now, :header => {})
    @valid_resp = stub('valid_resp', :authoritative= => nil, :header => {})

    @entry_valid   = mock('entry', :valid_for? => true, :response => @valid_resp)
    @entry_invalid = mock('entry', :valid_for? => false, :response => stub('invalid_resp'))

    @collection = Resourceful::CacheEntryCollection.new
  end

  it 'should find the right entry for a request' do
    @collection.instance_variable_set('@entries', [@entry_valid, @entry_invalid])
    @entry_valid.should_receive(:valid_for?).with(@request).and_return(true)
    @collection[@request].should == @valid_resp
  end

  it 'should be nil if no matching entry was found' do
    @collection.instance_variable_set('@entries', [@entry_invalid])
    @entry_invalid.should_receive(:valid_for?).with(@request).and_return(false)
    @collection[@request].should == nil
  end

  it 'should store an entry' do
    @collection[@request] = @valid_resp
    @collection.instance_variable_get("@entries").should have(1).items
  end

  it 'should replace an existing entry if the existing entry matches the request' do
    new_resp = stub('new_resp', :authoritative= => nil, :header => {})

    @collection[@request] = @valid_resp
    @collection[@request] = new_resp

    @collection.instance_variable_get("@entries").map{|it| it.response}.should include(new_resp)
    @collection.instance_variable_get("@entries").map{|it| it.response}.should_not include(@valid_resp)
  end

end

describe Resourceful::CacheEntry do
  before do
    @entry = Resourceful::CacheEntry.new(
      mock('original_request', :header => {'Accept' => 'text/plain'} , 
           :request_time => Time.utc(2008,5,16,0,0,0), :uri => 'http://foo.invalid'), 
      mock('response', :header => {'Vary' => 'Accept'})
    )

    @request = mock('request', :uri => 'http://foo.invalid')
  end

  describe "#valid_for?(a_request)" do 
    it "should true for request to URI w/ matching header " do
      @entry.valid_for?(mock("new_request", 
                             :uri => 'http://foo.invalid', 
                             :header => {'Accept' => 'text/plain'})).should be_true
    end 

    it "should false for requests against different URIs even if headers match" do
      @entry.valid_for?(mock("new_request", :uri => 'http://bar.invalid', 
                             :header => {'Accept' => 'text/plain'})).should be_false
    end 

    it "should false for requests where headers don't match" do
      @entry.valid_for?(mock("new_request", :uri => 'http://foo.invalid', 
                             :header => {'Accept' => 'application/octet-stream'})).should be_false
    end 

    it "should be false if request has a varying header and the original request was missing that header" do 
      entry = Resourceful::CacheEntry.new(
                 mock('original_request', :header => {}, 
                      :request_time => Time.utc(2008,5,16,0,0,0), :uri => 'http://foo.invalid'), 
                 mock('response', :header => {'Vary' => 'Accept'}))

      entry.valid_for?(mock("new_request", :uri => 'http://foo.invalid', 
                             :header => {'Accept' => 'text/plain'})).should be_false
    end
  end

  describe '#select_request_headers' do
    before do
      @req_header = mock('header', :[] => nil)
      @request = mock('request', :header => @req_header)

      @resp_header = mock('header', :[] => nil)
      @response = mock('response', :header => @resp_header)
    end

    it 'should select the request headers from the Vary header' do
      @resp_header.should_receive(:[]).with('Vary')
      @entry.select_request_headers(@request, @response)
    end

    it 'should pull the values from the request that match keys in the vary header' do
      @resp_header.should_receive(:[]).with('Vary').twice.and_return(['foo', 'bar'])
      @req_header.should_receive(:[]).with('foo').and_return('oof')
      @req_header.should_receive(:[]).with('bar').and_return('rab')

      header = @entry.select_request_headers(@request, @response)
      header['foo'].should == 'oof'
      header['bar'].should == 'rab'
    end

    it 'should return a new Header object' do
      @entry.select_request_headers(@request, @response).should be_kind_of(Resourceful::Header)
    end
  end
end


