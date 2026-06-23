local M = {}

local uv = vim.uv or vim.loop
local TITLE = "GitGen"
local FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function notify(msg, level, opts)
  opts = opts or {}
  opts.title = opts.title or TITLE
  vim.notify(msg, level, opts)
end

function M.info(msg) notify(msg, vim.log.levels.INFO) end
function M.warn(msg) notify(msg, vim.log.levels.WARN) end
function M.error(msg) notify(msg, vim.log.levels.ERROR) end
function M.ok(msg) notify(msg, vim.log.levels.INFO) end

--- Start a spinner notification.
--- Returns a handle with `stop(message?, level?)`:
---   - message given -> replaces the spinner with a final notification
---   - no message     -> dismisses the spinner (when the backend supports it)
---
--- Animation only runs with snacks.nvim (LazyVim default), which can replace a
--- notification in place via `id`. With other backends we show a single static
--- notification to avoid spamming the history.
function M.spinner(text)
  local ok, Snacks = pcall(require, "snacks")
  local has_snacks = ok and Snacks.notifier ~= nil
  local id = "gitgen-" .. tostring(uv.hrtime())

  if not has_snacks then
    notify(text, vim.log.levels.INFO, { id = id, timeout = false })
    return {
      id = id,
      stop = function(message, level)
        if message then
          notify(message, level or vim.log.levels.INFO, { id = id, timeout = 3000 })
        end
      end,
    }
  end

  local idx, timer = 0, uv.new_timer()
  local function render()
    idx = (idx % #FRAMES) + 1
    vim.schedule(function()
      Snacks.notify(text, {
        id = id,
        icon = FRAMES[idx],
        level = vim.log.levels.INFO,
        timeout = false,
        title = TITLE,
      })
    end)
  end

  render()
  timer:start(100, 100, render)

  return {
    id = id,
    stop = function(message, level)
      if not timer:is_closing() then
        timer:stop()
        timer:close()
      end
      vim.schedule(function()
        if message then
          Snacks.notify(message, {
            id = id,
            level = level or vim.log.levels.INFO,
            timeout = 3000,
            title = TITLE,
          })
        else
          pcall(Snacks.notifier.hide, id)
        end
      end)
    end,
  }
end

return M
