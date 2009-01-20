require 'rubygems'
require 'pathname'
require 'spec'
require 'pp'
require 'facets'

$LOAD_PATH << Pathname(__FILE__).dirname + "../lib"
require 'resourceful/util'
require 'resourceful'
require 'resourceful/http_accessor'

require Pathname(__FILE__).dirname + 'simple_http_server'
