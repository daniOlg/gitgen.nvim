# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-06-22

### Added
- AI-powered commit message generation via the `claude` CLI
- PR creation for GitHub and Azure DevOps with AI-generated titles
- Interactive floating dashboard (`:GitGen`) with keyboard navigation
- Extensible action registry for the dashboard
- Extensible provider registry (GitHub, Azure DevOps built-in)
- Non-blocking async runtime based on Lua coroutines + `vim.system`
- Animated spinner notifications (snacks.nvim-aware)
- Default keymaps: `<leader>G` (dashboard), `<leader>gc` (commit AI), `<leader>gC` (commit manual), `<leader>gn` (PR → develop), `<leader>gN` (PR custom)
- Zero-config setup: works with `return { "daniOlg/gitgen.nvim" }`
