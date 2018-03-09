local request_access = require "kong.plugins.request-transformer.request_access"

-- Main ideas
-- Minimize ceremony: A plugin is a table with functions, not a class instance
--                    (we might provide a way to not do the "base" behavior, but
--                    the usual path is that we do it in all plugins by default)
-- 4 entries in the table :
-- * version:  Self-explanatory
-- * priority: This is just a "default value". It can be overriden by a
--             a priority value in the "plugin instance", when present.
-- * request:  The request arrives from downstream and it is passed to every
--             plugin, sorted by their priority, on every phase. So every plugin
--             can have a request.access phase, a request.log phase, etc. The functions
--             have this signature:
--
--             request.access = function(conf, req, var)
--
--             Where `conf` is the plugin configuration (including service_id and customer_id)
--             `req` is a kong-provided object which wraps things like ngx.* calls
--             and json parsing,
--             `var` is just a thin wrapper around ngx.var - this was all that was
--             needed by this plugin, others might need a `kong` parameter instead
--             so that this becomes `kong.var`. If that's the case I would put kong
--             as the first param, not the last.
--
--             See the `request_access.lua` file for more details about `req` methods
--
-- * response: not used in this plugin. The response comes back from upstream and is
--             passed on to plugins in reverse priority order. There's
--             response.access, response.log, and so on. The signature is:
--
--             response.access = function(conf, res, var)
--
--             where `conf` and `var` are the same as before, and `res` is a
--             kong object which wraps calls to `ngx` calls such as set_status
--
-- Challenges / undecided:
-- * where do we do commonly used stuff like parsing json? We could use `require` or
--   we could provide them inside the `kong` parameter mentioned before (kong.var instead
--   of var would also have kong.json.encode)
-- * How does one cancel a request and returns a result right away?

return {
  version = "1.0.0",
  priority = 10,
  request = {
    access = request_access,
  }
}
