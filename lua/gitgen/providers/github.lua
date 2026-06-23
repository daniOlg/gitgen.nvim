local util = require("gitgen.providers.util")
local config = require("gitgen.config")

local M = {}
M.name = "github"

function M.matches(url)
  return url:match("github%.com") ~= nil
end

function M.parse(url)
  -- https://github.com/{owner}/{repo}[.git]  OR  git@github.com:{owner}/{repo}[.git]
  local owner_repo = url:gsub("%.git$", ""):match("github%.com[:/](.+)$")
  if not owner_repo or owner_repo == "" then
    return nil, "could not parse GitHub repo from: " .. url
  end
  return {
    owner_repo = owner_repo,
    api_url = "https://api.github.com/repos/" .. owner_repo .. "/pulls",
  }
end

function M.token()
  local cfg = config.get().providers.github
  local tok = util.read_pat(cfg.pat_file)
  if tok then
    return tok
  end
  -- fall back to the gh CLI
  if vim.fn.executable("gh") == 1 then
    local res = vim.system({ "gh", "auth", "token" }, { text = true }):wait()
    if res.code == 0 then
      local t = vim.trim(res.stdout or "")
      if t ~= "" then
        return t
      end
    end
  end
  return nil, "missing " .. cfg.pat_file .. " (or run: gh auth login)"
end

function M.build_request(ctx)
  return {
    url = ctx.parsed.api_url,
    headers = {
      "Authorization: Bearer " .. ctx.token,
      "Accept: application/vnd.github+json",
      "Content-Type: application/json",
    },
    body = {
      head = ctx.branch,
      base = ctx.target,
      title = ctx.title,
      body = ctx.description,
    },
  }
end

function M.parse_response(data)
  if type(data) == "table" and data.number then
    return true, ("PR #%d created: %s"):format(data.number, data.title), data.html_url
  end

  local msg = (type(data) == "table" and data.message) or "unknown error"
  if type(data) == "table" and data.errors then
    local extra = {}
    for _, e in ipairs(data.errors) do
      table.insert(extra, e.message or e.code or vim.inspect(e))
    end
    if #extra > 0 then
      msg = msg .. " — " .. table.concat(extra, "; ")
    end
  end
  return false, msg, nil
end

return M
