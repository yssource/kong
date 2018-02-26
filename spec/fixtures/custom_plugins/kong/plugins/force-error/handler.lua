local BasePlugin = require "kong.plugins.base_plugin"


local ForceError = BasePlugin:extend()


ForceError.PRIORITY = 1000


function ForceError:new()
  ForceError.super.new(self, "force-error")
end

function ForceError:header_filter()
  ForceError.super.access(self)
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
end

return ForceError
