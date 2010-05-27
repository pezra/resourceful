
require File.dirname(__FILE__) + '/../spec_helper'
require 'resourceful'

describe Resourceful do

  before do
    @http = Resourceful::HttpAccessor.new
    if ENV['SPEC_LOGGING']
      @http.logger = Resourceful::StdOutLogger.new
    end
  end

  describe "redirects" do

    describe "remembering resources" do

      it 'should use the same resource object for the same uri' do
        resource_a = @http.resource("http://localhost:4567/code/302")
        resource_b = @http.resource("http://localhost:4567/code/302")

        resource_a.object_id.should === resource_b.object_id
      end

      it 'should use the same resource object even if the original url gets redirected' do
        uri = "http://localhost:4567/code/301?location=http://localhost:4567/code/200"
        resource_a = @http.resource(uri)
        resource_a.get
        resource_a.uri.should == "http://localhost:4567/code/200"

        resource_b = @http.resource(uri)
        resource_a.object_id.should === resource_b.object_id
        resource_b.uri.should == "http://localhost:4567/code/200"
      end
    end

  end

end

