local async = require("gitgen.async")
local git = require("gitgen.git")
local ai = require("gitgen.ai")
local ui = require("gitgen.ui")
local config = require("gitgen.config")

local M = {}

--- Commit staged changes. If `message` is empty, generate one with claude.
function M.run(message)
  async.run(function()
    if not git.is_repo() then
      ui.error("not a git repository")
      return
    end
    if not git.has_staged() then
      ui.warn("nothing staged — use 'git add' first")
      return
    end

    message = message and vim.trim(message) or ""

    if message == "" then
      local cfg = config.get().commit
      local sp = ui.spinner("Generating commit message...")
      local ctx = git.staged_context(cfg.max_diff)
      local msg, err = ai.generate(cfg.prompt, ctx, { model = cfg.model, effort = cfg.effort })
      if not msg then
        sp.stop(err or "could not generate a commit message", vim.log.levels.ERROR)
        return
      end
      sp.stop()
      message = msg
    end

    local res = async.system({ "git", "commit", "-m", message }, { text = true })
    if res.code ~= 0 then
      ui.error("git commit failed: " .. vim.trim(res.stderr or res.stdout or ""))
      return
    end
    ui.ok("✓ committed: " .. message)
  end)
end

return M
