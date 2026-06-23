local M = {}

local uv = vim.uv or vim.loop

--- Read the first line of a PAT file (path may use ~). Returns the token or nil.
function M.read_pat(path)
  path = vim.fn.expand(path)
  if not uv.fs_stat(path) then
    return nil
  end
  local lines = vim.fn.readfile(path)
  return lines[1] and vim.trim(lines[1]) or nil
end

return M
