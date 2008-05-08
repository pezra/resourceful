require 'rubygems'
require 'pathname'
require 'spec'
require 'pp'

$LOAD_PATH << Pathname(__FILE__).dirname + "../lib"

class Object
  def tap
    yield(self)
    self
  end
end


require Pathname(__FILE__).dirname + 'simple_http_server_shared_spec'
