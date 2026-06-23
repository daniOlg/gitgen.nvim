local util = require("gitgen.providers.util")
local config = require("gitgen.config")

local M = {}
M.name = "azure"

function M.matches(url)
  return url:match("dev%.azure%.com") ~= nil or url:match("visualstudio%.com") ~= nil
end

function M.parse(url)
  local org, project, repo

  if url:match("ssh%.dev%.azure%.com") then
    -- git@ssh.dev.azure.com:v3/{org}/{project}/{repo}
    local p = url:match(":v3/(.+)$")
    if p then
      org, project, repo = p:match("^([^/]+)/([^/]+)/(.+)$")
    end
  else
    -- https://[user@]dev.azure.com/{org}/{project}/_git/{repo}
    org, project, repo = url:match("dev%.azure%.com/([^/]+)/([^/]+)/_git/([^/]+)")
  end

  if not (org and project and repo) then
    return nil, "could not parse Azure repo from: " .. url
  end
  repo = repo:gsub("%.git$", "")

  local api_base = ("https://dev.azure.com/%s/%s/_apis/git/repositories/%s"):format(org, project, repo)
  return {
    org = org,
    project = project,
    repo = repo,
    api_url = api_base .. "/pullrequests?api-version=7.1",
  }
end

function M.token()
  local cfg = config.get().providers.azure
  local tok = util.read_pat(cfg.pat_file)
  if not tok then
    return nil, "missing " .. cfg.pat_file .. " (Azure DevOps PAT, scope: Code Read & Write)"
  end
  return tok
end

function M.build_request(ctx)
  -- Azure uses Basic auth with base64(":" .. PAT). vim.base64 needs Neovim 0.10+.
  local basic = vim.base64.encode(":" .. ctx.token)
  return {
    url = ctx.parsed.api_url,
    headers = {
      "Authorization: Basic " .. basic,
      "Content-Type: application/json",
    },
    body = {
      sourceRefName = "refs/heads/" .. ctx.branch,
      targetRefName = "refs/heads/" .. ctx.target,
      title = ctx.title,
      description = ctx.description,
    },
  }
end

function M.parse_response(data)
  if type(data) == "table" and data.pullRequestId then
    local msg = ("PR #%d created: %s"):format(data.pullRequestId, data.title)
    local url
    if data.repository and data.repository.webUrl then
      url = ("%s/pullrequest/%d"):format(data.repository.webUrl, data.pullRequestId)
    end
    return true, msg, url
  end

  local msg = (type(data) == "table" and data.message) or "unknown error"
  return false, msg, nil
end

return M
