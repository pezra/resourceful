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
    @request = mock('request', :resource => mock('resource', :uri => 'uri'))
    @response = mock('response', :authoritative= => nil, :cachable => true)

    @entry = mock('cache entry', :response => @response)

    @imcm = Resourceful::InMemoryCacheManager.new
    @imcm.instance_variable_set("@collection", {'uri' => {@request => @entry}})
  end


  it 'should lookup the response by request' do
    @imcm.lookup(@request).should == @response
  end

  it 'should set the response to non-authoritative' do
    @response.should_receive(:authoritative=).with(false)
    @imcm.lookup(@request)
  end

  it 'should store the response by request'

  it 'should not store an entry if the response is not cachable'

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


