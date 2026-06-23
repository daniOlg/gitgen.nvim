local async = require("gitgen.async")
local git = require("gitgen.git")
local ai = require("gitgen.ai")
local ui = require("gitgen.ui")
local config = require("gitgen.config")
local providers = require("gitgen.providers")

local M = {}

-- Parse `:GitGenPR` args.
--   first positional  -> target
--   second positional -> title
--   --id <X>          -> jira id (uppercased), appended to the description
local function parse_args(args)
  local target, title, jira_id
  local i = 1
  while i <= #args do
    local a = args[i]
    if a == "--id" then
      jira_id = args[i + 1]
      if not jira_id then
        return nil, "--id requires a value (e.g. --id OVD-138)"
      end
      jira_id = jira_id:upper()
      i = i + 2
    else
      if not target then
        target = a
      elseif not title then
        title = a
      else
        return nil, "unexpected argument: " .. a
      end
      i = i + 1
    end
  end
  return { target = target, title = title, jira_id = jira_id }
end

function M.run(args)
  local pa, perr = parse_args(args or {})
  if not pa then
    ui.error(perr)
    return
  end

  async.run(function()
    local cfg = config.get().pr

    if not git.is_repo() then
      ui.error("not a git repository")
      return
    end

    local target = pa.target or cfg.default_target
    local branch = git.current_branch()
    if branch == "" then
      ui.error("not on a branch (detached HEAD)")
      return
    end
    if branch == target then
      ui.error(("current branch IS the target branch ('%s')"):format(target))
      return
    end

    -- detect provider + parse remote
    local remote = git.remote_url("origin")
    if remote == "" then
      ui.error("could not read 'origin' remote url")
      return
    end
    local provider = providers.detect(remote)
    if not provider then
      ui.error("'origin' is neither Azure DevOps nor GitHub: " .. remote)
      return
    end
    local parsed, parse_err = provider.parse(remote)
    if not parsed then
      ui.error(parse_err)
      return
    end

    -- token (validated before any network work)
    local token, terr = provider.token()
    if not token then
      ui.error(terr)
      return
    end

    -- push branch + fetch target concurrently
    local sp = ui.spinner(("Pushing %s + fetching %s (%s)..."):format(branch, target, provider.name))
    local results = async.join({
      { { "git", "push", "-u", "origin", branch }, { text = true } },
      { { "git", "fetch", "origin", target, "--no-tags", "--quiet" }, { text = true } },
    })
    local push_res, fetch_res = results[1], results[2]

    if fetch_res.code ~= 0 then
      sp.stop(("could not fetch origin/%s (does the branch exist?)"):format(target), vim.log.levels.ERROR)
      return
    end
    if push_res.code ~= 0 then
      sp.stop("git push failed: " .. vim.trim(push_res.stderr or push_res.stdout or ""), vim.log.levels.ERROR)
      return
    end

    local commits = git.commits_against(target)
    if commits == "" then
      sp.stop(("no commits between origin/%s and HEAD"):format(target), vim.log.levels.ERROR)
      return
    end

    -- title: explicit > single-commit subject > claude
    local title = pa.title
    if not title or title == "" then
      local lines = vim.split(commits, "\n", { plain = true, trimempty = true })
      if #lines == 1 then
        title = lines[1]:gsub("^%- ", "")
      else
        sp.stop()
        sp = ui.spinner("Generating PR title...")
        local t, gerr = ai.generate(cfg.prompt, commits, { model = cfg.model, effort = cfg.effort })
        if not t then
          sp.stop(gerr or "could not generate PR title", vim.log.levels.ERROR)
          return
        end
        title = t
      end
    end

    -- description (+ jira link)
    local description = commits
    if pa.jira_id and cfg.jira_base_url then
      local jira_url = cfg.jira_base_url .. pa.jira_id
      description = commits .. "\n[" .. jira_url .. "](" .. jira_url .. ")"
    end

    -- create the PR
    local req = provider.build_request({
      branch = branch,
      target = target,
      title = title,
      description = description,
      token = token,
      parsed = parsed,
    })

    local curl = { "curl", "-s", "-X", "POST" }
    for _, h in ipairs(req.headers) do
      vim.list_extend(curl, { "-H", h })
    end
    vim.list_extend(curl, { "--data-binary", "@-", req.url })

    local res = async.system(curl, { stdin = vim.json.encode(req.body), text = true })
    if res.code ~= 0 then
      sp.stop("curl failed: " .. vim.trim(res.stderr or ""), vim.log.levels.ERROR)
      return
    end

    local ok_json, data = pcall(vim.json.decode, res.stdout or "")
    if not ok_json then
      sp.stop("bad response from API: " .. vim.trim(res.stdout or ""), vim.log.levels.ERROR)
      return
    end

    local ok, msg, url = provider.parse_response(data)
    if ok then
      sp.stop("✓ " .. msg .. (url and ("\n" .. url) or ""), vim.log.levels.INFO)
    else
      sp.stop("✗ " .. msg, vim.log.levels.ERROR)
    end
  end)
end

return M
