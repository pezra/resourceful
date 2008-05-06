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
