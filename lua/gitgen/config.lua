local M = {}

local defaults = {
  -- AI provider settings.
  -- `provider` selects the active AI; the provider name is also the key for
  -- provider-specific options below (e.g. ai.claude, ai.gemini, ai.copilot).
  ai = {
    provider = "claude",
    claude = {
      cmd    = "claude",
      model  = "haiku",
      effort = nil, -- nil = omit --effort flag
    },
    -- gemini = { cmd = "gemini", model = "gemini-2.0-flash" },
    -- copilot = { ... },
  },

  commit = {
    max_diff = 12000, -- cap the staged diff fed to the AI (chars)
    -- model / effort override the AI provider defaults for commits only
    prompt = [[
## Your task
Based on the above changes, write a single-line commit.
Allowed prefixes:
- feat: new feature or enhancement
- fix: bug or general fix
- docs: documentation
- style: formatting only
- refactor: no functional change
- ci: ci/cd changes
Format: "<prefix>: <oneline description>".
English, lowercase, concise. No body, no quotes, no backticks.
Output only the commit message line, nothing else.
]],
  },

  pr = {
    default_target = "develop",
    jira_base_url = nil, -- e.g. "https://company.atlassian.net/browse/"
    model = "haiku",
    effort = "medium",
    prompt = [[
Write a single-line pull request title that summarizes these commits.
Title must be in english, lowercase, concise.
Output ONLY the title, nothing else.
]],
  },

  -- Where each provider finds its token. Extend with new providers here.
  providers = {
    github = { pat_file = "~/.github-pat" }, -- falls back to `gh auth token`
    azure = { pat_file = "~/.azure-devops-pat" },
  },

  -- Default keymaps. Set to false to disable all default keys.
  -- Each entry: { lhs, desc, action } where action is a string key.
  keys = {
    dashboard = "<leader>G",
    commit_ai = "<leader>gc",
    commit_manual = "<leader>gC",
    pr_develop = "<leader>gn",
    pr_custom = "<leader>gN",
  },
}

local options

function M.setup(opts)
  options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  return options
end

function M.get()
  if not options then
    options = vim.deepcopy(defaults)
  end
  return options
end

return M
