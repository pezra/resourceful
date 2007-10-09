
require 'advanced_http/http_accessor'

# AdvancedHttp is a facade that allows convenient access to the
# functionality provided by the AdvancedHttp library.
module AdvancedHttp
  REV = %r{\d+}.match("$Revision: 6761$")[0]
  VERSION = %r{rel/([^/]+)}.match("$HeadURL: svn+ssh://devutil-p.boulder.api.local/svn/rortal-plugins/trunk/active_rest/lib/active_rest/http_service_pro.rb$")[1] rescue "devel"

  def default_user_agent_str
    "ActiveRest/#{VERSION}(#{REV}) Ruby/#{RUBY_VERSION}"
  end

  alias user_agent_str default_user_agent_str

  
end
