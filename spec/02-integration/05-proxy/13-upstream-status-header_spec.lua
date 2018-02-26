local helpers = require "spec.helpers"
local constants = require "kong.constants"


describe(constants.HEADERS.UPSTREAM_STATUS .. " header", function()
  local client

  setup(function()
    assert(helpers.dao.apis:insert {
      name         = "upstream-header-1",
      hosts        = { "upstream-header-1.com" },
      upstream_url = helpers.mock_upstream_url,
    })
    local api2 = assert(helpers.dao.apis:insert {
      name         = "upstream-header-2",
      hosts        = { "upstream-header-2.com" },
      upstream_url = helpers.mock_upstream_url,
    })
    assert(helpers.dao.plugins:insert {
      name   = "force-error",
      api_id = api2.id,
    })
    assert(helpers.start_kong({
      nginx_conf = "spec/fixtures/custom_nginx.template",
	  custom_plugins = "force-error",
    }))
    client = helpers.proxy_client()
  end)

  teardown(function()
    if client then
      client:close()
    end
    helpers.stop_kong()
  end)

  it("should be same as upstream staus code", function()
    local res = assert(client:send {
      method  = "GET",
      path    = "/",
      headers = {
        host  = "upstream-header-1.com",
      }
    })

    assert.res_status(200, res)
    assert.equal('200', res.headers[constants.HEADERS.UPSTREAM_STATUS])
  end)

  it("should be same as upstream staus code even if plugin changes status code", function()
    local res = assert(client:send {
      method  = "GET",
      path    = "/status/200",
      headers = {
        ["Host"]  = "upstream-header-2.com",
      }
    })
    assert.res_status(500, res)
    assert.equal('200', res.headers[constants.HEADERS.UPSTREAM_STATUS])
  end)
end)
