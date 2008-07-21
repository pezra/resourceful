require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/cache_manager'

describe Resourceful::CacheManager do
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

  describe '#select_request_headers' do
    before do
      @req_header = mock('header', :[] => nil)
      @request = mock('request', :header => @req_header)

      @resp_header = mock('header', :[] => nil)
      @response = mock('response', :header => @resp_header)
    end

    it 'should select the request headers from the Vary header' do
      @resp_header.should_receive(:[]).with('Vary')
      @cm.select_request_headers(@request, @response)
    end

    it 'should pull the values from the request that match keys in the vary header' do
      @resp_header.should_receive(:[]).with('Vary').twice.and_return(['foo', 'bar'])
      @req_header.should_receive(:[]).with('foo').and_return('oof')
      @req_header.should_receive(:[]).with('bar').and_return('rab')

      header = @cm.select_request_headers(@request, @response)
      header['foo'].should == 'oof'
      header['bar'].should == 'rab'
    end

    it 'should return a new Header object' do
      @cm.select_request_headers(@request, @response).should be_kind_of(Resourceful::Header)
    end
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
    @response = mock('response', :header => {})

    @entry = mock('cache entry', :response => @response, :valid_for? => true)
    Resourceful::InMemoryCacheManager::CacheEntry.stub!(:new).and_return(@entry)

    @imcm = Resourceful::InMemoryCacheManager.new
  end

  describe 'finding' do
    before do
      @response.stub!(:authoritative=)
      @imcm.instance_variable_set("@collection", {'uri' => {@request => @entry}})
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
    before do
      @response.stub!(:cachable?).and_return(true)
    end

    it 'should make a new cache entry' do
      Resourceful::InMemoryCacheManager::CacheEntry.should_receive(:new).with(
        Time.utc(2008,5,22,15,00),
        {},
        @response
      )

      @imcm.store(@request, @response)
    end

    it 'should store the response entity by request' do
      @imcm.store(@request, @response)
      col = @imcm.instance_variable_get("@collection")
      col['uri'][@request].response.should == @response
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

end

describe Resourceful::InMemoryCacheManager::CacheEntryCollection do
  before do
    @entry_valid   = mock('entry', :valid_for? => true)
    @entry_invalid = mock('entry', :valid_for? => false)

    @request = mock('request')

    @collection = Resourceful::InMemoryCacheManager::CacheEntryCollection.new
  end

  it 'should find the right entry for a request' do
    @collection.instance_variable_set('@entries', [@entry_valid, @entry_invalid])
    @entry_valid.should_receive(:valid_for?).with(@request).and_return(true)
    @collection[@request].should == @entry_valid
  end

  it 'should be nil if no matching entry was found' do
    @collection.instance_variable_set('@entries', [@entry_invalid])
    @entry_invalid.should_receive(:valid_for?).with(@request).and_return(false)
    @collection[@request].should == nil
  end

  it 'should store an entry' do
    @collection[@request] = @entry_valid
    @collection.instance_variable_get("@entries").should include(@entry_valid)
  end

  it 'should replace an existing entry if the existing entry matches the request' do
    @new_entry = mock('entry', :valid_for? => true)

    @collection[@request] = @entry_valid
    @collection[@request] = @new_entry

    @collection.instance_variable_get("@entries").should include(@new_entry)
    @collection.instance_variable_get("@entries").should_not include(@entry_valid)
  end

end

describe Resourceful::InMemoryCacheManager::CacheEntry do
  before do
    @entry = Resourceful::InMemoryCacheManager::CacheEntry.new(
      Time.utc(2008,5,16,0,0,0), {'Content-Type' => 'text/plain'}, mock('response')
    )

    @request = mock('request')
  end

  [:request_time, :request_vary_headers, :response, :valid_for?].each do |method|
    it "should respond to ##{method}" do
      @entry.should respond_to(method)
    end
  end

  it 'should be valid for a request if all the vary headers match' do
    @request.stub!(:header).and_return({'Content-Type' => 'text/plain'})
    @entry.valid_for?(@request).should be_true
  end

  it 'should not be valid for a request if not all the vary headers match' do
    @request.stub!(:header).and_return({'Content-Type' => 'text/html'})
    @entry.valid_for?(@request).should be_false
  end

end


