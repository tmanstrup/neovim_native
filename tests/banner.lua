local M = {}

-- Keep floating window and buffer ids
local banner_buf = nil
local banner_win = nil

--------------------------------------------------
-- Collect currently listed buffers
--------------------------------------------------
local function get_buffers()
  local bufs = vim.api.nvim_list_bufs()
  local results = {}

  for _, b in ipairs(bufs) do
    if vim.api.nvim_buf_is_loaded(b) and vim.api.nvim_get_option_value("buflisted", { buf = b }) then
      local name = vim.api.nvim_buf_get_name(b)
      if name == "" then
        name = "[No Name]"
      else
        name = vim.fn.fnamemodify(name, ":t")
      end
      table.insert(results, b .. ": " .. name)
    end
  end

  return results
end

--------------------------------------------------
-- Render banner text into buffer
--------------------------------------------------
local function render_banner()
  if not (banner_buf and vim.api.nvim_buf_is_valid(banner_buf)) then
    return
  end

  local buffers = get_buffers()

  local lines = { "== Open Buffers ==" }
  vim.list_extend(lines, buffers)

  vim.api.nvim_buf_set_lines(banner_buf, 0, -1, false, lines)
end

--------------------------------------------------
-- Create floating window banner
--------------------------------------------------
function M.open_banner()
  -- If exists, reuse
  if banner_win and vim.api.nvim_win_is_valid(banner_win) then
    vim.api.nvim_set_current_win(banner_win)
    render_banner()
    return
  end

  banner_buf = vim.api.nvim_create_buf(false, true) -- nofile buffer

  local width = math.floor(vim.o.columns * 0.35)
  local height = math.floor(vim.o.lines * 0.4)

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  }

  banner_win = vim.api.nvim_open_win(banner_buf, true, opts)

  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = banner_buf })
  vim.api.nvim_set_option_value("wrap", false, { win = banner_win })

  render_banner()
end

--------------------------------------------------
-- Refresh banner if window still open
--------------------------------------------------
function M.refresh_if_open()
  if banner_win and vim.api.nvim_win_is_valid(banner_win) then
    render_banner()
  end
end

return M

