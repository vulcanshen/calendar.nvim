local M = {}

local config = {
  time_format = "%H:%M:%S",
  highlights = {
    CalendarTitle = { default = true, link = "Title" },
    CalendarHeader = { default = true, link = "Keyword" },
    CalendarToday = { default = true, reverse = true, bold = true },
    CalendarSep = { default = true, link = "FloatBorder" },
    CalendarTime = { default = true, bold = true },
    CalendarDay = { default = true, link = "Normal" },
  },
}

local state = {
  buf = nil,
  win = nil,
  timer = nil,
  parent_win = nil,
  enabled = true,
  time_line_idx = nil,
  last_pw = nil,
  last_ph = nil,
  last_day = nil,
  last_month = nil,
}

local ns = vim.api.nvim_create_namespace("calendar")

local MONTH_NAMES = {
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
}

local function days_in_month(y, m)
  local t = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if m == 2 and ((y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0) then
    return 29
  end
  return t[m]
end

local function center(s, w)
  local dw = vim.fn.strdisplaywidth(s)
  local pad = math.floor((w - dw) / 2)
  return string.rep(" ", math.max(0, pad)) .. s
end

local function is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

local function find_explorer_win()
  local ok, pickers = pcall(function()
    return Snacks.picker.get({ source = "explorer" })
  end)
  if not ok or not pickers or #pickers == 0 then
    return nil
  end
  local explorer = pickers[1]
  if explorer.list and explorer.list.win and explorer.list.win.win then
    local win = explorer.list.win.win
    if vim.api.nvim_win_is_valid(win) then
      return win
    end
  end
  return nil
end

local function set_highlights()
  for name, hl_opts in pairs(config.highlights) do
    vim.api.nvim_set_hl(0, name, hl_opts)
  end
end

local function render()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end
  if not is_open() then
    return
  end
  if not (state.parent_win and vim.api.nvim_win_is_valid(state.parent_win)) then
    return
  end

  local pw = vim.api.nvim_win_get_width(state.parent_win)
  local ph = vim.api.nvim_win_get_height(state.parent_win)

  local now = os.date("*t")
  local y, m, d = now.year, now.month, now.day

  local first_wday = tonumber(os.date("%w", os.time({ year = y, month = m, day = 1, hour = 12 })))
  local ndays = days_in_month(y, m)
  local grid_rows = math.ceil((first_wday + ndays) / 7)
  -- top sep + title + blank + header + grid + separator + time
  local needed_height = 4 + grid_rows + 1 + 1

  -- Reposition to stay at bottom of explorer
  pcall(vim.api.nvim_win_set_config, state.win, {
    relative = "win",
    win = state.parent_win,
    row = ph - needed_height,
    col = 0,
    width = pw,
    height = needed_height,
  })

  local w = vim.api.nvim_win_get_width(state.win)

  local lines = {}
  local highlights = {}
  local hl_line, hl_col_s, hl_col_e
  local today_col = nil

  -- Top separator
  table.insert(lines, string.rep("─", w))
  table.insert(highlights, { line = #lines - 1, hl = "CalendarSep" })

  -- Title
  table.insert(lines, center(MONTH_NAMES[m] .. " " .. y, w))
  table.insert(highlights, { line = #lines - 1, hl = "CalendarTitle" })
  table.insert(lines, "")

  -- Weekday header
  table.insert(lines, center("Su Mo Tu We Th Fr Sa", w))
  table.insert(highlights, { line = #lines - 1, hl = "CalendarHeader" })

  -- Day grid
  local grid_pad = math.max(0, math.floor((w - 20) / 2))
  local col = first_wday
  local row = {}

  for _ = 1, first_wday do
    table.insert(row, "  ")
  end

  for dd = 1, ndays do
    table.insert(row, string.format("%2d", dd))
    if dd == d then
      today_col = col
    end

    col = col + 1
    if col == 7 then
      table.insert(lines, string.rep(" ", grid_pad) .. table.concat(row, " "))
      table.insert(highlights, { line = #lines - 1, hl = "CalendarDay" })
      if today_col ~= nil then
        hl_line = #lines - 1
        hl_col_s = grid_pad + today_col * 3
        hl_col_e = hl_col_s + 2
        today_col = nil
      end
      row = {}
      col = 0
    end
  end

  if #row > 0 then
    table.insert(lines, string.rep(" ", grid_pad) .. table.concat(row, " "))
    table.insert(highlights, { line = #lines - 1, hl = "CalendarDay" })
    if today_col ~= nil then
      hl_line = #lines - 1
      hl_col_s = grid_pad + today_col * 3
      hl_col_e = hl_col_s + 2
    end
  end

  -- Separator
  local sep_line = #lines
  table.insert(lines, string.rep("─", w))
  table.insert(highlights, { line = sep_line, hl = "CalendarSep" })

  -- Time
  local time_str = os.date(config.time_format)
  if now.sec % 2 == 1 then
    time_str = time_str:gsub(":", " ")
  end
  state.time_line_idx = #lines
  table.insert(lines, center(time_str, w))
  table.insert(highlights, { line = state.time_line_idx, hl = "CalendarTime" })

  -- Today highlight
  if hl_line then
    table.insert(highlights, { line = hl_line, hl = "CalendarToday", col_s = hl_col_s, col_e = hl_col_e })
  end

  -- Write buffer
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for _, h in ipairs(highlights) do
    if h.col_s then
      vim.api.nvim_buf_add_highlight(state.buf, ns, h.hl, h.line, h.col_s, h.col_e)
    else
      vim.api.nvim_buf_add_highlight(state.buf, ns, h.hl, h.line, 0, -1)
    end
  end

  -- Cache for tick
  state.last_pw = pw
  state.last_ph = ph
  state.last_day = d
  state.last_month = m
end

-- Only update the time line each second to avoid full re-render flicker
local function tick()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end
  if not is_open() then
    return
  end
  if not (state.parent_win and vim.api.nvim_win_is_valid(state.parent_win)) then
    return
  end

  -- Full re-render if parent size or date changed
  local pw = vim.api.nvim_win_get_width(state.parent_win)
  local ph = vim.api.nvim_win_get_height(state.parent_win)
  local now = os.date("*t")
  if pw ~= state.last_pw or ph ~= state.last_ph or now.day ~= state.last_day or now.month ~= state.last_month then
    render()
    return
  end

  if state.time_line_idx == nil then
    render()
    return
  end

  -- Only update time text
  local w = vim.api.nvim_win_get_width(state.win)
  local time_str = os.date(config.time_format)
  if now.sec % 2 == 1 then
    time_str = time_str:gsub(":", " ")
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, state.time_line_idx, state.time_line_idx + 1, false, { center(time_str, w) })
  vim.bo[state.buf].modifiable = false

  -- Re-apply highlight only for the time line
  vim.api.nvim_buf_clear_namespace(state.buf, ns, state.time_line_idx, state.time_line_idx + 1)
  vim.api.nvim_buf_add_highlight(state.buf, ns, "CalendarTime", state.time_line_idx, 0, -1)
end

local function cleanup()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
  local win = state.win
  state.win = nil
  state.buf = nil
  state.parent_win = nil
  state.time_line_idx = nil
  state.last_pw = nil
  state.last_ph = nil
  state.last_day = nil
  state.last_month = nil
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  pcall(vim.api.nvim_del_augroup_by_name, "CalendarWatch")
end

function M.open()
  if is_open() then
    return
  end
  local parent = find_explorer_win()
  if not parent then
    return
  end

  state.enabled = true
  state.parent_win = parent

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].filetype = "calendar"

  local pw = vim.api.nvim_win_get_width(parent)
  local ph = vim.api.nvim_win_get_height(parent)

  local now = os.date("*t")
  local first_wday = tonumber(os.date("%w", os.time({ year = now.year, month = now.month, day = 1, hour = 12 })))
  local grid_rows = math.ceil((first_wday + days_in_month(now.year, now.month)) / 7)
  local height = 4 + grid_rows + 1 + 1

  state.win = vim.api.nvim_open_win(state.buf, false, {
    relative = "win",
    win = parent,
    row = ph - height,
    col = 0,
    width = pw,
    height = height,
    style = "minimal",
    focusable = false,
    zindex = 100,
  })

  vim.wo[state.win].wrap = false
  vim.wo[state.win].cursorline = false
  vim.wo[state.win].spell = false
  vim.wo[state.win].list = false

  render()

  state.timer = vim.uv.new_timer()
  state.timer:start(1000, 1000, vim.schedule_wrap(tick))

  local group = vim.api.nvim_create_augroup("CalendarWatch", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(parent),
    once = true,
    callback = function()
      vim.schedule(function()
        state.enabled = true
        cleanup()
      end)
    end,
  })

  -- Hide calendar when another floating window gets focus (e.g. search picker),
  -- show again when focus returns to explorer or a regular window
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if not is_open() then
        return
      end
      local win = vim.api.nvim_get_current_win()
      if win == state.win then
        return
      end
      if win == state.parent_win then
        pcall(vim.api.nvim_win_set_config, state.win, { hide = false })
        return
      end
      local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
      if ok and cfg.relative ~= "" then
        pcall(vim.api.nvim_win_set_config, state.win, { hide = true })
      else
        pcall(vim.api.nvim_win_set_config, state.win, { hide = false })
      end
    end,
  })
end

function M.close()
  state.enabled = false
  cleanup()
end

function M.toggle()
  if is_open() then
    M.close()
  else
    state.enabled = true
    M.open()
  end
end

function M.setup(opts)
  opts = opts or {}
  local user_hl = opts.highlights
  opts.highlights = nil
  config = vim.tbl_deep_extend("force", config, opts)
  if user_hl then
    for name, hl in pairs(user_hl) do
      config.highlights[name] = hl
    end
  end
  set_highlights()

  local group = vim.api.nvim_create_augroup("CalendarSetup", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = set_highlights,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "snacks_picker_list",
    callback = function()
      vim.defer_fn(function()
        if state.enabled and not is_open() then
          M.open()
        end
      end, 100)
    end,
  })

  vim.defer_fn(function()
    if state.enabled and not is_open() then
      M.open()
    end
  end, 500)

  vim.api.nvim_create_user_command("CalendarToggle", M.toggle, {})
  vim.api.nvim_create_user_command("CalendarOpen", M.open, {})
  vim.api.nvim_create_user_command("CalendarClose", M.close, {})
end

return M
