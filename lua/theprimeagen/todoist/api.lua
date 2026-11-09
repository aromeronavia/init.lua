-- Thin async client for the Todoist API v1 (https://developer.todoist.com/api/v1/).
-- Every callback runs on the main loop, so callers may touch buffers directly.

local M = {}

local BASE_URL = "https://api.todoist.com/api/v1"
local PAGE_SIZE = 200

local function read_token()
  local token = vim.env.TODOIST_API_TOKEN
  if token == nil or token == "" then
    return nil
  end
  return token
end

local function build_url(path, query)
  local url = BASE_URL .. path
  local params = {}
  for key, value in pairs(query or {}) do
    params[#params + 1] = key .. "=" .. vim.uri_encode(tostring(value), "rfc3986")
  end
  if #params > 0 then
    url = url .. "?" .. table.concat(params, "&")
  end
  return url
end

--- Sends one request. cb(err, decoded_body).
--- The token goes to curl on stdin (`-K -`) so it never shows up in `ps`.
function M.request(method, path, opts, cb)
  local token = read_token()
  if not token then
    return cb("TODOIST_API_TOKEN is not set (Todoist → Settings → Integrations → Developer)")
  end

  local cmd = {
    "curl", "-sS", "-K", "-",
    "-X", method,
    "-H", "Content-Type: application/json",
    "-w", "\n%{http_code}",
  }
  if opts.body then
    vim.list_extend(cmd, { "--data-binary", vim.json.encode(opts.body) })
  end
  cmd[#cmd + 1] = build_url(path, opts.query)

  local curl_config = ('header = "Authorization: Bearer %s"\n'):format(token)
  vim.system(cmd, { stdin = curl_config, text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        return cb("curl failed: " .. vim.trim(result.stderr or ""))
      end
      local body, status = result.stdout:match("^(.*)\n(%d+)$")
      status = tonumber(status)
      if not status then
        return cb("unexpected response from curl")
      end
      if status >= 300 then
        return cb(("HTTP %d: %s"):format(status, vim.trim(body)))
      end
      if body == "" or body == "null" then
        return cb(nil, nil)
      end
      local ok, decoded = pcall(vim.json.decode, body, { luanil = { object = true, array = true } })
      if not ok then
        return cb("could not decode response: " .. decoded)
      end
      cb(nil, decoded)
    end)
  end)
end

--- Follows `next_cursor` until every page is read. cb(err, items).
local function list_all(path, query, cb)
  local items = {}
  local function fetch_page(cursor)
    local page_query = vim.tbl_extend("force", query or {}, { limit = PAGE_SIZE, cursor = cursor })
    M.request("GET", path, { query = page_query }, function(err, data)
      if err then
        return cb(err)
      end
      vim.list_extend(items, data.results or {})
      if data.next_cursor then
        fetch_page(data.next_cursor)
      else
        cb(nil, items)
      end
    end)
  end
  fetch_page(nil)
end

--- Loads projects and active tasks together. A nil filter means every active task;
--- otherwise it is a Todoist filter query such as "today | overdue".
--- cb(err, projects, tasks)
function M.fetch(filter, cb)
  local results, pending, failed = {}, 2, false
  local function collect(key)
    return function(err, items)
      if failed then
        return
      end
      if err then
        failed = true
        return cb(err)
      end
      results[key] = items
      pending = pending - 1
      if pending == 0 then
        cb(nil, results.projects, results.tasks)
      end
    end
  end

  list_all("/projects", nil, collect("projects"))
  if filter then
    list_all("/tasks/filter", { query = filter }, collect("tasks"))
  else
    list_all("/tasks", nil, collect("tasks"))
  end
end

function M.create_task(body, cb)
  M.request("POST", "/tasks", { body = body }, cb)
end

--- Natural-language add, e.g. "Pay rent tomorrow #Home p1".
function M.quick_add(text, cb)
  M.request("POST", "/tasks/quick", { body = { text = text } }, cb)
end

function M.update_task(id, body, cb)
  M.request("POST", "/tasks/" .. id, { body = body }, cb)
end

function M.move_task(id, project_id, cb)
  M.request("POST", "/tasks/" .. id .. "/move", { body = { project_id = project_id } }, cb)
end

function M.close_task(id, cb)
  M.request("POST", "/tasks/" .. id .. "/close", {}, cb)
end

function M.delete_task(id, cb)
  M.request("DELETE", "/tasks/" .. id, {}, cb)
end

return M
