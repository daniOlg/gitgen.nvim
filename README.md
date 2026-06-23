# gitgen.nvim

AI-powered git commits and Pull Requests from Neovim, using the [`claude`](https://docs.anthropic.com/en/docs/claude-code) CLI.

- Generates commit messages from your staged diff
- Opens PRs on **GitHub** and **Azure DevOps** with AI-written titles
- Non-blocking — uses Lua coroutines + `vim.system`, never freezes the editor
- Animated spinner (snacks.nvim-aware) while the AI runs
- Interactive floating dashboard with keyboard navigation
- Extensible action and provider registries
- **Zero-config** — works with just `return { "daniOlg/gitgen.nvim" }`

## Requirements

- Neovim **0.10+** (`vim.system`, `vim.base64`, `vim.uv`)
- [`claude` CLI](https://docs.anthropic.com/en/docs/claude-code) in `$PATH`
- `git` and `curl` in `$PATH`
- A token per provider:
  - **GitHub** → `~/.github-pat`, or `gh auth login`
  - **Azure DevOps** → `~/.azure-devops-pat` (scope: *Code Read & Write*)
- Optional: [snacks.nvim](https://github.com/folke/snacks.nvim) for animated spinner

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

Zero-config (default keymaps are set automatically):

```lua
return { "daniOlg/gitgen.nvim" }
```

With options:

```lua
{
  "daniOlg/gitgen.nvim",
  opts = {
    pr = {
      default_target = "main",
      jira_base_url  = "https://company.atlassian.net/browse/",
    },
  },
}
```

See [`example-lazy-spec.lua`](example-lazy-spec.lua) for the full spec with all options documented.

## Default Keymaps

| Keymap | Action |
|--------|--------|
| `<leader>G` | Open GitGen dashboard |
| `<leader>gc` | Commit (AI message) |
| `<leader>gC` | Commit (manual message) |
| `<leader>gn` | PR → default target (`develop`) |
| `<leader>gN` | PR (custom args) |

> `<leader>G` (capital G) is chosen to avoid conflicts with lazygit's `<leader>gg` / `<leader>gG`.

Disable all defaults with `keys = false` in opts, or override individual keys:

```lua
opts = {
  keys = {
    dashboard     = "<leader>G",
    commit_ai     = "<leader>gc",
    commit_manual = "<leader>gC",
    pr_develop    = "<leader>gn",
    pr_custom     = "<leader>gN",
  },
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:GitGen` | Open the interactive dashboard |
| `:GitGenCommit` | Commit staged changes with an AI-generated message |
| `:GitGenCommit fix: my msg` | Commit with the given message |
| `:GitGenPR` | Open a PR against `default_target` |
| `:GitGenPR qa` | Open a PR against `qa` |
| `:GitGenPR develop "title"` | PR with a custom title |
| `:GitGenPR --id PROJ-42` | Append a Jira link to the PR description |

## Dashboard

`:GitGen` opens a floating window with the current repo context and a list of actions:

```
╭─────────────── GitGen ────────────────╮
│  Repo:     my-project                 │
│  Branch:   feat/new-login             │
│  Staged:   3 files                    │
│  Provider: github                     │
│                                       │
│  Actions                              │
│                                       │
│  c   Commit (AI message)    Generate… │
│  C   Commit (manual msg)    Type …    │
│  p   PR → develop           Open a …  │
│  Q   PR → qa                Open a …  │
│  P   PR (custom args)       target …  │
│  r   Refresh                Recalc…   │
╰───────────────────────────────────────╯
```

| Key | Action |
|-----|--------|
| `j` / `k`, `↑` / `↓` | Move between actions |
| `<CR>` | Execute selected action |
| `c` | Commit (AI message) |
| `C` | Commit (manual message) |
| `p` | PR → develop |
| `Q` | PR → qa |
| `P` | PR (custom args) |
| `r` | Refresh context |
| `q` / `<Esc>` | Close |

## Configuration

All options and their defaults:

```lua
require("gitgen").setup({
  claude = {
    cmd    = "claude",  -- path to the claude binary
    model  = "haiku",   -- default model for all AI calls
    effort = nil,       -- nil = omit --effort flag
  },

  commit = {
    max_diff = 12000,   -- max chars of staged diff fed to claude
    -- model / effort can override `claude` for commits only
    prompt = [[
## Your task
Based on the above changes, write a single-line commit.
Allowed prefixes: feat, fix, docs, style, refactor, ci.
Format: "<prefix>: <description>". English, lowercase, concise.
Output only the commit message line, nothing else.
]],
  },

  pr = {
    default_target = "develop",
    jira_base_url  = nil,          -- e.g. "https://co.atlassian.net/browse/"
    model          = "haiku",
    effort         = "medium",
    prompt         = "...",
  },

  providers = {
    github = { pat_file = "~/.github-pat" },
    azure  = { pat_file = "~/.azure-devops-pat" },
  },

  keys = {
    dashboard     = "<leader>G",
    commit_ai     = "<leader>gc",
    commit_manual = "<leader>gC",
    pr_develop    = "<leader>gn",
    pr_custom     = "<leader>gN",
  },
})
```

## Extending

### Add a dashboard action

```lua
require("gitgen.dashboard").register({
  key   = "s",
  label = "Status",
  desc  = "Run :Git (fugitive)",
  run   = function() vim.cmd("Git") end,
})
```

### Add a provider (e.g. GitLab)

1. Create `lua/gitgen/providers/gitlab.lua` implementing:
   `name`, `matches`, `parse`, `token`, `build_request`, `parse_response`.
2. Register it:
   ```lua
   require("gitgen.providers").register(require("gitgen.providers.gitlab"))
   ```

## Architecture

```
lua/gitgen/
├── init.lua          setup() + user commands + default keymaps + public API
├── config.lua        defaults + deep-merge
├── async.lua         coroutine runtime over vim.system (run/system/join)
├── git.lua           synchronous git helpers (branch, staged, remote, diff)
├── claude.lua        claude CLI wrapper (-p, model, effort, stdin)
├── ui.lua            notify + animated spinner (snacks-aware)
├── commit.lua        commit flow
├── pr.lua            PR flow (push + fetch + title + provider API)
├── dashboard.lua     floating window: context + extensible action registry
└── providers/
    ├── init.lua      registry + auto-detect from remote URL
    ├── util.lua      PAT file reader
    ├── github.lua    GitHub REST API
    └── azure.lua     Azure DevOps REST API
```

The async backbone (`async.lua`) wraps `vim.system` callbacks in a coroutine
runtime: `async.system(cmd)` suspends the coroutine and resumes it when the
process exits, so `commit.lua` and `pr.lua` read top-to-bottom. `async.join`
runs multiple commands (e.g. push + fetch) concurrently.

## License

[MIT](LICENSE)
