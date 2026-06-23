-- AI provider: claude CLI
-- Interface: name, generate(prompt, stdin, opts) -> text, err
local async = require("gitgen.async")

local M = {}
M.name = "claude"

function M.generate(prompt, stdin, opts)
  opts = opts or {}
  local cfg = require("gitgen.config").get().ai.claude

  local args = {
    cfg.cmd or "claude",
    "--model", opts.model or cfg.model or "haiku",
    "-p", "--no-session-persistence",
  }
  local effort = opts.effort or cfg.effort
  if effort and effort ~= "" then
    vim.list_extend(args, { "--effort", effort })
  end
  table.insert(args, prompt)

  local res = async.system(args, { stdin = stdin, text = true })
  if res.code ~= 0 then
    return nil, "claude failed: " .. vim.trim(res.stderr or res.stdout or "")
  end

  local out = vim.split(res.stdout or "", "\n", { plain = true })[1] or ""
  out = out:gsub("[`\"]", "")
  out = vim.trim(out)
  if out == "" then
    return nil, "claude returned an empty message"
  end
  return out, nil
end

return M
