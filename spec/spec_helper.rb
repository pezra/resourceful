require 'rubygems'
require 'pathname'
require 'spec'
require 'pp'
require 'facets'

#$LOAD_PATH << Pathname(__FILE__).dirname + "../lib"
$LOAD_PATH << File.dirname(__FILE__) + "../lib"
require 'resourceful/util'
require 'resourceful'
require 'resourceful/http_accessor'

require Pathname(__FILE__).dirname + 'simple_http_server_shared_spec'


