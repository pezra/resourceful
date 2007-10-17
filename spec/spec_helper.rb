require 'rubygems'
require 'pathname'
require 'spec'

$LOAD_PATH << Pathname(__FILE__).dirname + "../lib"

Spec::Runner.configure do |config|
  config.mock_with :mocha
end
