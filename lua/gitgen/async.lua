-- Minimal coroutine-based async runtime.
-- Lets us write sequential-looking code on top of vim.system callbacks,
-- so commit.lua / pr.lua read top-to-bottom instead of nesting callbacks.
local M = {}

--- Run `fn` as a coroutine.
--- A coroutine "awaits" by yielding a thunk: a function(resume) that does the
--- async work and calls resume(...) with the result when finished.
function M.run(fn)
  local co = coroutine.create(fn)
  local function step(...)
    local ok, thunk = coroutine.resume(co, ...)
    if not ok then
      vim.schedule(function()
        vim.notify("gitgen async error: " .. tostring(thunk), vim.log.levels.ERROR)
      end)
      return
    end
    if coroutine.status(co) ~= "dead" and type(thunk) == "function" then
      thunk(step)
    end
  end
  step()
end

--- Await a single vim.system command. Returns its completed result table
--- ({ code, stdout, stderr }).
function M.system(cmd, opts)
  opts = opts or {}
  return coroutine.yield(function(resume)
    vim.system(cmd, opts, function(res)
      vim.schedule(function()
        resume(res)
      end)
    end)
  end)
end

--- Await several commands concurrently. `cmds` is a list of { cmd, opts }.
--- Returns a list of results in the same order.
function M.join(cmds)
  return coroutine.yield(function(resume)
    local results, remaining = {}, #cmds
    if remaining == 0 then
      return vim.schedule(function()
        resume(results)
      end)
    end
    for i, c in ipairs(cmds) do
      vim.system(c[1], c[2] or {}, function(res)
        results[i] = res
        remaining = remaining - 1
        if remaining == 0 then
          vim.schedule(function()
            resume(results)
          end)
        end
      end)
    end
  end)
end

return M
