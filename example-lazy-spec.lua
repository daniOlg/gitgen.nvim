-- Copy to ~/.config/nvim/lua/plugins/gitgen.lua
--
-- ZERO CONFIG — this single line is enough; commands + default keymaps work:
--
--   return { "daniOlg/gitgen.nvim" }
--
-- The spec below shows all available options.
return {
  {
    "daniOlg/gitgen.nvim",
    -- dir = vim.fn.expand("~/projects/gitgen.nvim"),  -- local development

    -- `opts` is only needed to override defaults.
    -- Without it, commands and keymaps are still registered automatically.
    opts = {
      -- claude CLI settings
      -- claude = { cmd = "claude", model = "haiku", effort = nil },

      -- Commit generation
      -- commit = { max_diff = 12000 },

      -- PR creation
      -- pr = {
      --   default_target = "develop",
      --   jira_base_url  = "https://company.atlassian.net/browse/",
      -- },

      -- Default keymaps (set keys = false to disable all):
      -- <leader>G  → GitGen dashboard  (no conflict with lazygit <leader>gg)
      -- <leader>gc → GitGenCommit (AI)
      -- <leader>gC → GitGenCommit (manual)
      -- <leader>gn → GitGenPR → develop
      -- <leader>gN → GitGenPR (custom args)
      --
      -- keys = false,
      -- keys = {
      --   dashboard     = "<leader>G",
      --   commit_ai     = "<leader>gc",
      --   commit_manual = "<leader>gC",
      --   pr_develop    = "<leader>gn",
      --   pr_custom     = "<leader>gN",
      -- },
    },
  },
}
