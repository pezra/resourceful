require 'pathname'

def add_to_load_path(dir)
  dir = Pathname(dir).expand_path
  return if $LOAD_PATH.any?{|load_path_dir| Pathname(load_path_dir).expand_path == dir}
  # dir is not already in load path

  $LOAD_PATH.unshift(dir)
end

add_to_load_path Pathname(__FILE__).dirname
add_to_load_path Pathname(__FILE__).dirname + '../ext'

require 'resourceful/util'

require 'resourceful/header'
require 'resourceful/http_accessor'

# Resourceful is a library that provides a high level HTTP interface.
module Resourceful
  VERSION = "0.5.0"
  RESOURCEFUL_USER_AGENT_TOKEN = "Resourceful/#{VERSION}(Ruby/#{RUBY_VERSION})"

end
