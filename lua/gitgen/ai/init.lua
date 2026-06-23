-- AI provider registry. A provider is a table implementing:
--   name                              string
--   generate(prompt, stdin, opts)     -> text:string|nil, err:string|nil
--
-- `opts` passed to generate(): { model?, effort? } — provider-level overrides.
-- The provider reads its own defaults from config.ai.<name>.
--
-- To add a new provider (e.g. copilot, gemini), create lua/gitgen/ai/<name>.lua
-- implementing the interface above, then register it below — nothing else changes.
local M = {}

local registry = {}

function M.register(provider)
  registry[provider.name] = provider
end

--- Return the provider configured in config.ai.provider, or err if unknown.
function M.current()
  local cfg = require("gitgen.config").get().ai
  local name = cfg.provider or "claude"
  local p = registry[name]
  if not p then
    return nil, ("unknown AI provider '%s' — available: %s"):format(
      name, table.concat(vim.tbl_keys(registry), ", ")
    )
  end
  return p
end

--- Generate text using the active provider.
--- opts: { model?, effort? } — passed through to the provider.
function M.generate(prompt, stdin, opts)
  local p, err = M.current()
  if not p then
    return nil, err
  end
  return p.generate(prompt, stdin, opts)
end

M.register(require("gitgen.ai.claude"))
-- M.register(require("gitgen.ai.copilot"))
-- M.register(require("gitgen.ai.gemini"))

return M
