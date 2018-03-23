local vers       = require "kong.public.versions"
local ver        = require "version"


local vers_count = #vers
local range      = ver.range
local set        = ver.set


return function(version)
  local v

  if not version then
    v = ver(vers[vers_count])
  else
    local consumer = ver.strict(version)
  end
end
