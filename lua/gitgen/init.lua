local config = require("gitgen.config")

local M = {}

-- Commands are registered at module-load time so they work even without
-- an explicit setup() call (e.g. lazy.nvim spec with no `opts`).
vim.api.nvim_create_user_command("GitGen", function()
  require("gitgen.dashboard").open()
end, { desc = "Open the GitGen dashboard" })

vim.api.nvim_create_user_command("GitGenCommit", function(cmd)
  require("gitgen.commit").run(cmd.args)
end, {
  nargs = "*",
  desc = "Commit staged changes (AI message if none given)",
})

vim.api.nvim_create_user_command("GitGenPR", function(cmd)
  require("gitgen.pr").run(cmd.fargs)
end, {
  nargs = "*",
  desc = "Open a PR (Azure DevOps / GitHub) with an AI-generated title",
  complete = function()
    return { "develop", "qa", "main", "master", "--id" }
  end,
})

local _keymaps_set = false

local function setup_keymaps(keys)
  if keys == false or _keymaps_set then
    return
  end
  _keymaps_set = true

  local function map(lhs, desc, fn)
    if lhs and lhs ~= "" then
      vim.keymap.set("n", lhs, fn, { desc = desc, silent = true })
    end
  end

  map(keys.dashboard, "GitGen dashboard", function() M.dashboard() end)
  map(keys.commit_ai, "GitGen: commit (AI message)", function() M.commit() end)
  map(keys.commit_manual, "GitGen: commit (manual message)", function()
    vim.ui.input({ prompt = "Commit message: " }, function(msg)
      if msg and msg ~= "" then
        M.commit(msg)
      end
    end)
  end)
  map(keys.pr_develop, "GitGen: PR → develop", function() M.pr({}) end)
  map(keys.pr_custom, "GitGen: PR (custom args)", function()
    vim.ui.input({ prompt = 'PR args (e.g. qa "title" --id OVD-138): ' }, function(a)
      if a and a ~= "" then
        M.pr(vim.split(a, "%s+", { trimempty = true }))
      end
    end)
  end)
end

-- Auto-apply default keymaps when loaded without an explicit setup() call.
-- vim.schedule covers both cases: startup load and lazy cmd-triggered load
-- (where VimEnter has already fired).
vim.schedule(function()
  if not _keymaps_set then
    setup_keymaps(config.get().keys)
  end
end)

-- setup() is only needed to override defaults. lazy.nvim calls it when `opts`
-- is present in the plugin spec; otherwise the module-level defaults apply.
function M.setup(opts)
  config.setup(opts)
  -- keymaps: re-apply immediately with the new config (skip the scheduled call)
  _keymaps_set = false
  setup_keymaps(config.get().keys)
end

-- Public Lua API
function M.commit(message)
  require("gitgen.commit").run(message)
end

function M.pr(args)
  require("gitgen.pr").run(args)
end

function M.dashboard()
  require("gitgen.dashboard").open()
end

return M
