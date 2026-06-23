local M = {}

-- Synchronous helper for fast local reads (microseconds; no UI cost).
-- Returns (trimmed_stdout, err).
local function sync(args)
  local res = vim.system(vim.list_extend({ "git" }, args), { text = true }):wait()
  if res.code ~= 0 then
    return "", vim.trim(res.stderr or "")
  end
  return vim.trim(res.stdout or ""), nil
end

function M.is_repo()
  local out = sync({ "rev-parse", "--is-inside-work-tree" })
  return out == "true"
end

function M.has_staged()
  -- `git diff --cached --quiet` exits 1 when something is staged.
  local res = vim.system({ "git", "diff", "--cached", "--quiet" }):wait()
  return res.code ~= 0
end

function M.current_branch()
  return (sync({ "branch", "--show-current" }))
end

--- Absolute path of the repository root ("" outside a work tree).
function M.root()
  return (sync({ "rev-parse", "--show-toplevel" }))
end

--- Number of staged files (derived from `git diff --cached --name-only`).
function M.staged_count()
  local out = sync({ "diff", "--cached", "--name-only" })
  if out == "" then
    return 0
  end
  return #vim.split(out, "\n", { plain = true, trimempty = true })
end

function M.remote_url(remote)
  return (sync({ "remote", "get-url", remote or "origin" }))
end

--- Context blob fed to claude to write the commit message.
function M.staged_context(max_diff)
  max_diff = max_diff or 12000
  local parts = {}
  local function section(title, args)
    table.insert(parts, "=== " .. title .. " ===\n" .. (sync(args)))
  end
  section("Last 5 commits", { "log", "--oneline", "-5" })
  section("Current branch", { "branch", "--show-current" })
  section("Staged diff summary", { "diff", "--cached", "--stat" })

  local diff = (sync({ "diff", "--cached" }))
  if #diff > max_diff then
    diff = diff:sub(1, max_diff)
  end
  table.insert(parts, "=== Staged diff ===\n" .. diff)

  return table.concat(parts, "\n\n")
end

--- Commits between origin/<target> and HEAD, as a markdown bullet list.
function M.commits_against(target)
  return (sync({ "log", "--format=- %s", "origin/" .. target .. "..HEAD" }))
end

return M
