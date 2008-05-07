require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/response'

describe Resourceful::Response do
  before do
    @net_http = mock('net_http')
    Net::HTTP::Get.stub!(:new).and_return(@net_http)

    @response = Resourceful::Response.new
  end

  describe 'init' do

    it 'should be instantiatable' do
      @response.should be_instance_of(Resourceful::Response)
    end

  end

end

