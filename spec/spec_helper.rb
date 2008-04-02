require 'rubygems'
require 'pathname'
require 'spec'
require 'pp'

$LOAD_PATH << Pathname(__FILE__).dirname + "../lib"

Spec::Runner.configure do |config|
  config.mock_with :mocha
end

class Object
  def tap
    yield(self)
    self
  end
end
