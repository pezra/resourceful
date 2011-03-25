require 'spec_helper'
require 'resourceful'

describe Resourceful do

  describe 'setting headers' do
    before do
      @http = Resourceful::HttpAccessor.new
      @resource = @http.resource("http://localhost:4567/header")
    end

    it 'should handle "Content-Type"' do
      resp = @resource.post("asdf", :content_type => 'foo/bar')

      header = YAML.load(resp.body)

      header.should have_key('CONTENT_TYPE')
      header['CONTENT_TYPE'].should == 'foo/bar'

    end

  end
end

