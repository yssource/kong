local table_insert = table.insert
local type = type

local _M = {}

local HOST = "host"

local function iter(config_array)
  return function(config_array, i, previous_name, previous_value)
    i = i + 1
    local current_pair = config_array[i]
    if current_pair == nil then -- n + 1
      return nil
    end

    local current_name, current_value = current_pair:match("^([^:]+):*(.-)$")
    if current_value == "" then
      current_value = nil
    end

    return i, current_name, current_value
  end, config_array, 0
end

local function append_value(current_value, value)
  local current_value_type = type(current_value)

  if current_value_type  == "string" then
    return { current_value, value }
  elseif current_value_type  == "table" then
    table_insert(current_value, value)
    return current_value
  else
    return { value }
  end
end

local function transform_headers(conf, req, var)
  local headers = req:get_headers()

  -- Remove header(s)
  for _, name, value in iter(conf.remove.headers) do
    headers[name] = nil
  end

  -- Rename headers(s)
  for _, old_name, new_name in iter(conf.rename.headers) do
    if headers[old_name] then
      headers[new_name] = headers[old_name]
      headers[old_name] = nil
    end
  end

  -- Replace header(s)
  for _, name, value in iter(conf.replace.headers) do
    if headers[name] then
      headers[name] = value
      if name:lower() == HOST then -- Host header has a special treatment
        var.upstream_host = value
      end
    end
  end

  -- Add header(s)
  for _, name, value in iter(conf.add.headers) do
    if not headers[name] then
      headers[name] = value
      if name:lower() == HOST then -- Host header has a special treatment
        var.upstream_host = value
      end
    end
  end

  -- Append header(s)
  for _, name, value in iter(conf.append.headers) do
    headers[name] = append_value(headers[name], value)
    if name:lower() == HOST then -- Host header has a special treatment
      var.upstream_host = value
    end
  end

  req:set_headers(headers)
end

local function transform_querystring(conf, req)
  local query = req:get_query()
  local transformed = false

  -- Remove querystring(s)
  if conf.remove.querystring then
    for _, name, value in iter(conf.remove.querystring) do
      query[name] = nil
      transformed = true
    end
  end

  -- Rename querystring(s)
  if conf.rename.querystring then
    for _, old_name, new_name in iter(conf.rename.querystring) do
      local value = query[old_name]
      query[old_name] = nil
      query[new_name] = value
      transformed = true
    end
  end

  -- Replace querystring(s)
  if conf.replace.querystring then
    for _, name, value in iter(conf.replace.querystring) do
      if query[name] then
        query[name] = value
        transformed = true
      end
    end
  end

  -- Add querystring(s)
  if conf.add.querystring then
    for _, name, value in iter(conf.add.querystring) do
      if not query[name] then
        query[name] = value
        transformed = true
      end
    end
  end

  -- Append querystring(s)
  if conf.append.querystring then
    for _, name, value in iter(conf.append.querystring) do
      query[name] = append_value(query[name], value)
      transformed = true
    end
  end

  if transformed then
    req:set_query(query)
  end
end

local function transform_body(conf, req)
  local pct = req:get_parsed_content_type()
  if pct ~= "url-encoded" and pct ~= "multipart" and pct ~= "json"
  or #conf.rename.body < 1
  and #conf.remove.body < 1 and #conf.replace.body < 1
  and #conf.add.body < 1 and #conf.append.body < 1
  then
    return
  end

  local parameters, err = req:get_decoded_body()
  if type(parameters) ~= "table" then
    return nil, err
  end

  local transformed = false
  if req.content_length > 0 then
    for _, name, value in iter(conf.remove.body) do
      parameters[name] = nil
      transformed = true
    end

    for _, old_name, new_name in iter(conf.rename.body) do
      local value = parameters[old_name]
      parameters[new_name] = value
      parameters[old_name] = nil
      transformed = true
    end

    for _, name, value in iter(conf.replace.body) do
      if parameters[name] then
        parameters[name] = value
        transformed = true
      end
    end
  end

  for _, name, value in iter(conf.add.body) do
    if parameters[name] == nil then
      parameters[name] = value
      transformed = true
    end
  end

  for _, name, value in iter(conf.append.body) do
    local old_value = parameters[name]
    parameters[name] = append_value(old_value, value)
    transformed = true
  end

  if transformed then
    req:set_decoded_body(parameters)
  end
end

local function transform_method(conf, req)
  local m = conf.http_method
  if type(m) ~= "string" then
    return
  end

  req:set_method(m)
  if m == "GET" or m == "HEAD" or m == "TRACE"
  and req:get_parsed_content_type() == "url-encoded"
  then
      local query = req:get_query()
      for name, value in pairs(req:get_decoded_body()) do
        query[name] = value
      end
      req:set_query(query)
    end
  end
end


-- `conf` is a regular table with the plugin conf, including service_id and consumer_id
-- `req` is an object with (at least) the current entries:
-- * `req:set_method(str)` changes the request method, calling ngx["HTTP_" .. x] = ...:upper()
-- * `req:get_query()` returns a table which represents the query string
-- * `req:set_query(tbl)` replaces the current query string with a new one, calling to ngx.set_query
-- * `req:get_decoded_body()` returns a table which represents the decoded body - so if the request is
--       JSON, then the body will be decoded as json, etc.
-- * `req:set_decoded_body(tbl)` sets the whole body in one go (slow)
-- * `req:get_headers()` returns a table representing all the headers
-- * `req:set_headers(tbl)` allows setting all the headers in one go
-- * `req:get_parsed_content_type()` returns the string 'json', 'form' or 'multipart' (and maybe others)
--
-- `var` is a thin wrapper (maybe just a rename of) ngx.var
--
-- With this variables we move a lot of repetitive stuff to the req object (json parsing, multipart, etc) yet
-- we leave the "iteration over the config" and the "append mechanics" on the plugin itself

local response_access = function(conf, req, var)
  transform_method(conf, req)
  transform_body(conf, req)
  transform_headers(conf, req, var)
  transform_querystring(conf, req)
end

return response_access
