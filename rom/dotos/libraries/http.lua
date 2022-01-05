-- HTTP library --

-- native http.request: function(
--  url:string[, post:string[, headers:table[, binarymode:boolean]]])
--    post is the data to POST.  otherwise a GET is sent.
--  OR: function(parameters:table)
--    where parameters = {
--      url = string,     -- the URL
--      body = string,    -- the data to POST/PATCH/PUT
--      headers = table,  -- request headers
--      binary = boolean, -- self explanatory
--      method = string}  -- the HTTP method to use - one of:
--                            - GET
--                            - POST
--                            - HEAD
--                            - OPTIONS
--                            - PUT
--                            - DELETE
--                            - PATCH
--                            - TRACE
--   
-- native http.checkURL: function(url:string)
--    url is a URL to try to reach.  queues a http_check event with the result.
-- native http.websocket(url:string[, headers:table])
--    url is the url to which to open a websocket.  queues a websocket_success
--    event on success, and websocket_failure on failure.
-- native http.addListener(port:number) (CraftOS-PC only)
--    add a listener on the specified port.  when that port receives data,
--    the listener queues a http_request(port:number, request, response).
--    !!the response is not send until response.close() is called!!
-- native http.removeListener(port:number) (CraftOS-PC only)
--    remove the listener from that port

local http = package.loaded.rawhttp

local lib = {}
lib.async = http

function lib.request(url, post, headers, binary, method)
  if type(url) ~= "table" then
    url = {
      url = url,
      body = post,
      headers = headers,
      binary = binary,
      method = method or (post and "POST") or "GET"
    }
  end

  checkArg("url", url.url, "string")
  checkArg("body", url.body, "string", "nil")
  checkArg("headers", url.headers, "table", "nil")
  checkArg("binary", url.binary, "boolean")
  checkArg("method", url.method, "string")

  local ok, err = http.request(url)
  if not ok then
    return nil, err
  end

  while true do
    local sig, a, b, c = coroutine.yield()
    if sig == "http_success" and a == url.url then
      return b
    elseif sig == "http_failure" and a == url.url then
      return nil, b, c
    end
  end
end

function lib.checkURL(url)
  checkArg(1, url, "string")

  local ok, err = http.checkURL(url)
  if not ok then
    return nil, err
  end
  
  local sig, a, b
  repeat
    sig, a, b = coroutine.yield()
  until sig == "http_check" and a == url

  return a, b
end

function lib.websocket(url, headers)
  checkArg(1, url, "string")
  checkArg(2, headers, "string")

  local ok, err = http.websocket(url, headers)
  if not ok then
    return nil, err
  end

  while true do
    local sig, a, b, c = coroutine.yield()
    if sig == "websocket_success" and a == url then
      return b, c
    elseif sig == "websocket_failure" and a == url then
      return nil, b
    end
  end
end

if http.addListener then
  function lib.listen(port, callback)
    checkArg(1, port, "number")
    checkArg(2, callback, "function")
    http.addListener(port)

    while true do
      local sig, a, b, c = coroutine.yield()
      if sig == "stop_listener" and a == port then
        http.removeListener(port)
        break
      elseif sig == "http_request" and  a == port then
        if not callback(b, c) then
          http.removeListener(port)
          break
        end
      end
    end
  end
else
  function lib.listen()
    error("This functionality requires CraftOS-PC", 0)
  end
end

return lib
