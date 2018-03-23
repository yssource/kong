local singletons = require "kong.singletons"

local _SSLCertificates = {}

function _SSLCertificates:delete(primary_key)
  local dao = singletons.dao
  local snis, err = dao.ssl_servers_names:find_all({
    ssl_certificate_id = primary_key.id,
  })
  if err then
    return nil, err
  end

  for i = 1, #snis do
    local _, err = dao.ssl_servers_names:delete({
      name = snis[i].name,
    })
    if err then
      return nil, err
    end
  end

  return self.super.delete(self, primary_key)
end

return _SSLCertificates
