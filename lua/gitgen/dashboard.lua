-- Floating dashboard: shows repo context and a keyboard-navigable list of
-- actions. It only orchestrates — every action delegates to the existing
-- commit/pr modules. Actions live in an extensible registry, mirroring the
-- provider registry in providers/init.lua (use M.register to add more).
local git = require("gitgen.git")
local providers = require("gitgen.providers")

local M = {}

local ns = vim.api.nvim_create_namespace("gitgen-dashboard")

-- State of the currently open dashboard (nil when closed):
--   { buf, win, action_lines = { [0-based line] = action index }, first, last }
local current

-- Action registry. Each entry: { key, label, desc, run, keep_open? }.
--   key        single char that triggers the action from inside the buffer
--   run()      performs the action (delegates to commit/pr)
--   keep_open  if true the dashboard is NOT closed before run() (refresh only)
local actions = {}

--- Register a new action. Same pattern as providers.register: append an entry
--- and it shows up in the dashboard with no other changes.
function M.register(action)
  table.insert(actions, action)
end

-- Gather the repo context shown in the header. Computed fresh on open/refresh.
local function build_context()
  local ctx = { is_repo = git.is_repo() }
  if not ctx.is_repo then
    return ctx
  end

  local root = git.root()
  ctx.repo = root ~= "" and vim.fs.basename(root) or "—"

  local branch = git.current_branch()
  ctx.branch = branch ~= "" and branch or "(detached HEAD)"

  ctx.staged = git.staged_count()

  local remote = git.remote_url("origin")
  local provider = remote ~= "" and providers.detect(remote) or nil
  ctx.provider = provider and provider.name or "—"

  return ctx
end

-- Build the buffer lines plus a map from 0-based line -> action index.
local function build_lines(ctx)
  local lines, action_lines = {}, {}
  local function add(s)
    lines[#lines + 1] = s
  end

  if not ctx.is_repo then
    add("  Not a git repository.")
    add("")
    add("  Press q or <Esc> to close.")
    return lines, action_lines
  end

  add("  Repo:     " .. ctx.repo)
  add("  Branch:   " .. ctx.branch)
  add("  Staged:   " .. ctx.staged .. (ctx.staged == 1 and " file" or " files"))
  add("  Provider: " .. ctx.provider)
  add("")
  add("  Actions")
  add("")

  -- pad the label column by display width (labels contain multibyte chars)
  for i, a in ipairs(actions) do
    local pad = string.rep(" ", math.max(0, 26 - vim.fn.strdisplaywidth(a.label)))
    add(("  %s   %s%s %s"):format(a.key, a.label, pad, a.desc))
    action_lines[#lines - 1] = i -- 0-based line just added
  end

  return lines, action_lines
end

-- Highlight the action line under the cursor (cleared + redrawn each move).
local function highlight()
  local st = current
  if not st or not st.first then
    return
  end
  vim.api.nvim_buf_clear_namespace(st.buf, ns, 0, -1)
  local row = vim.api.nvim_win_get_cursor(st.win)[1] - 1 -- 0-based
  if st.action_lines[row] then
    vim.api.nvim_buf_set_extmark(st.buf, ns, row, 0, {
      line_hl_group = "Visual",
      hl_eol = true,
    })
  end
end

-- Keep the cursor within the action range and refresh the highlight.
local function clamp()
  local st = current
  if not st or not st.first then
    return
  end
  local row = vim.api.nvim_win_get_cursor(st.win)[1] - 1
  local target = math.max(st.first, math.min(st.last, row))
  if target ~= row then
    vim.api.nvim_win_set_cursor(st.win, { target + 1, 0 })
  end
  highlight()
end

-- Move the cursor by `delta` action lines, clamped to the action range.
local function move(delta)
  local st = current
  if not st or not st.first then
    return
  end
  local row = vim.api.nvim_win_get_cursor(st.win)[1] - 1
  local target = math.max(st.first, math.min(st.last, row + delta))
  vim.api.nvim_win_set_cursor(st.win, { target + 1, 0 })
  highlight()
end

local function close()
  local st = current
  current = nil
  if st and st.win and vim.api.nvim_win_is_valid(st.win) then
    vim.api.nvim_win_close(st.win, true)
  end
end

-- Recompute context, redraw the buffer, resize the window and reset the cursor.
local function render()
  local st = current
  if not st or not vim.api.nvim_buf_is_valid(st.buf) then
    return
  end

  local ctx = build_context()
  local lines, action_lines = build_lines(ctx)
  st.action_lines = action_lines

  -- action range (contiguous block); nil when there are no actions
  st.first, st.last = nil, nil
  for line in pairs(action_lines) do
    st.first = st.first and math.min(st.first, line) or line
    st.last = st.last and math.max(st.last, line) or line
  end

  vim.bo[st.buf].modifiable = true
  vim.api.nvim_buf_set_lines(st.buf, 0, -1, false, lines)
  vim.bo[st.buf].modifiable = false

  -- size + center the window to fit the content
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.max(width + 2, 36)
  local height = #lines
  vim.api.nvim_win_set_config(st.win, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2 - 1),
    col = math.floor((vim.o.columns - width) / 2),
  })

  if st.first then
    vim.api.nvim_win_set_cursor(st.win, { st.first + 1, 0 })
  end
  highlight()
end

-- Run the action on the given line (or index). The window is closed BEFORE
-- running async / vim.ui.input flows so they don't fight for focus; refresh
-- (keep_open) is the only action that redraws in place.
local function execute(idx)
  local action = actions[idx]
  if not action then
    return
  end
  if action.keep_open then
    action.run()
    return
  end
  close()
  action.run()
end

local function execute_under_cursor()
  local st = current
  if not st or not st.win or not vim.api.nvim_win_is_valid(st.win) then
    return
  end
  local row = vim.api.nvim_win_get_cursor(st.win)[1] - 1
  execute(st.action_lines[row])
end

-- Wire up the buffer-local mappings.
local function set_keymaps(buf)
  local function map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, silent = true })
  end

  map("j", function() move(1) end)
  map("<Down>", function() move(1) end)
  map("k", function() move(-1) end)
  map("<Up>", function() move(-1) end)
  map("<CR>", execute_under_cursor)

  -- each action's own key triggers it directly
  for i, a in ipairs(actions) do
    map(a.key, function() execute(i) end)
  end

  -- close (q/<Esc>) is mapped last so it wins over any action key collision
  map("q", close)
  map("<Esc>", close)
end

--- Open the dashboard. Focuses the existing one if already open.
function M.open()
  if current and current.win and vim.api.nvim_win_is_valid(current.win) then
    vim.api.nvim_set_current_win(current.win)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = 36,
    height = 1,
    row = 0,
    col = 0,
    style = "minimal",
    border = "rounded",
    title = " GitGen ",
    title_pos = "center",
  })
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = false
  vim.wo[win].wrap = false

  current = { buf = buf, win = win, action_lines = {} }

  set_keymaps(buf)

  -- keep the cursor inside the action range + track the highlight
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = clamp,
  })
  -- drop our state if the window goes away by other means
  vim.api.nvim_create_autocmd({ "WinClosed", "BufWipeout" }, {
    buffer = buf,
    callback = function()
      current = nil
    end,
  })

  render()
end

-- Default actions. Adding one is a single entry here (or M.register elsewhere).
M.register({
  key = "c",
  label = "Commit (AI message)",
  desc = "Generate the message with claude",
  run = function()
    require("gitgen.commit").run("")
  end,
})
M.register({
  key = "C",
  label = "Commit (manual message)",
  desc = "Type your own message",
  run = function()
    vim.ui.input({ prompt = "Commit message: " }, function(msg)
      if msg and msg ~= "" then
        require("gitgen.commit").run(msg)
      end
    end)
  end,
})
M.register({
  key = "p",
  label = "PR → develop",
  desc = "Open a PR against develop",
  run = function()
    require("gitgen.pr").run({})
  end,
})
M.register({
  key = "Q",
  label = "PR → qa",
  desc = "Open a PR against qa",
  run = function()
    require("gitgen.pr").run({ "qa" })
  end,
})
M.register({
  key = "P",
  label = "PR (custom args)",
  desc = "target / title / --id ...",
  run = function()
    vim.ui.input({ prompt = 'PR args (e.g. qa "title" --id OVD-138): ' }, function(a)
      if a and a ~= "" then
        require("gitgen.pr").run(vim.split(a, "%s+", { trimempty = true }))
      end
    end)
  end,
})
M.register({
  key = "r",
  label = "Refresh",
  desc = "Recalculate context and redraw",
  keep_open = true,
  run = render,
})

return M
