-- Fuzzy File Finder using ripgrep with split view
-- Save this as ~/.config/nvim/lua/fuzzy_finder.lua

local M = {}

local popup_buf = nil
local popup_win = nil
local results = {}
local selected_idx = 1

-- Function to close the popup
local function close_popup()
  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_close(popup_win, true)
  end
  if popup_buf and vim.api.nvim_buf_is_valid(popup_buf) then
    vim.api.nvim_buf_delete(popup_buf, { force = true })
  end
  popup_win = nil
  popup_buf = nil
  results = {}
  selected_idx = 1
end

-- Function to open selected file at the matched line
local function open_file()
  if #results == 0 then
    return
  end
  
  local result = results[selected_idx]
  close_popup()
  
  vim.cmd('edit ' .. vim.fn.fnameescape(result.file))
  if result.line_number then
    vim.api.nvim_win_set_cursor(0, {result.line_number, 0})
  end
end

-- Function to truncate string with ellipsis
local function truncate(str, max_len)
  if #str <= max_len then
    return str
  end
  return str:sub(1, max_len - 3) .. '...'
end

-- Function to update the display
local function update_display(query, left_width, right_width)
  if not popup_buf or not vim.api.nvim_buf_is_valid(popup_buf) then
    return
  end
  
  local lines = {}
  local search_line = '> ' .. query
  table.insert(lines, search_line)
  table.insert(lines, string.rep('─', left_width + right_width + 3))
  
  if #results == 0 then
    table.insert(lines, '(no results)')
  else
    for i, result in ipairs(results) do
      local file_part = truncate(result.file, left_width)
      local match_part = truncate(result.match or '', right_width)
      
      -- Pad file part to align columns
      file_part = file_part .. string.rep(' ', left_width - #file_part)
      
      local line = file_part .. ' │ ' .. match_part
      table.insert(lines, line)
    end
  end
  
  vim.api.nvim_buf_set_option(popup_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, lines)
  
  -- Clear previous highlights
  vim.api.nvim_buf_clear_namespace(popup_buf, -1, 0, -1)
  
  -- Highlight selected line (offset by 2 for search line and separator)
  if selected_idx > 0 and selected_idx <= #results then
    vim.api.nvim_buf_add_highlight(popup_buf, -1, 'Visual', selected_idx + 1, 0, -1)
  end
end

-- Function to search files using ripgrep
local function search_files(query)
  local cwd = vim.fn.getcwd()
  
  if not query or query == '' then
    -- If no query, show all files
    local cmd = 'cd "' .. cwd .. '" && rg --files 2>/dev/null'
    local handle = io.popen(cmd)
    if not handle then
      return {}
    end
    
    local output = handle:read('*a')
    handle:close()
    
    local files = {}
    for file in output:gmatch('[^\r\n]+') do
      table.insert(files, {
        file = file,
        match = '',
        line_number = nil
      })
      if #files >= 100 then
        break
      end
    end
    return files
  end
  
  -- Search file contents with ripgrep, showing line numbers and matches
  local escaped_query = query:gsub('"', '\\"')
  local cmd = 'cd "' .. cwd .. '" && rg --line-number --no-heading "' .. escaped_query .. '" 2>/dev/null'
  
  local handle = io.popen(cmd)
  if not handle then
    return {}
  end
  
  local output = handle:read('*a')
  handle:close()
  
  local files = {}
  local seen_files = {}
  
  for line in output:gmatch('[^\r\n]+') do
    local file, line_num, match = line:match('^([^:]+):(%d+):(.*)$')
    if file and not seen_files[file] then
      seen_files[file] = true
      -- Trim whitespace from match
      match = match:gsub('^%s+', ''):gsub('%s+$', '')
      table.insert(files, {
        file = file,
        line_number = tonumber(line_num),
        match = match
      })
      if #files >= 100 then
        break
      end
    end
  end
  
  return files
end

-- Function to handle search updates
local function on_search_change(left_width, right_width)
  local current_line = vim.api.nvim_get_current_line()
  local query = current_line:match('^> (.*)') or ''
  
  results = search_files(query)
  selected_idx = 1
  
  update_display(query, left_width, right_width)
  
  -- Move cursor back to search line
  vim.api.nvim_win_set_cursor(popup_win, {1, #current_line})
end

-- Function to move selection
local function move_selection(direction, left_width, right_width)
  if #results == 0 then
    return
  end
  
  selected_idx = selected_idx + direction
  if selected_idx < 1 then
    selected_idx = #results
  elseif selected_idx > #results then
    selected_idx = 1
  end
  
  local current_line = vim.api.nvim_get_current_line()
  local query = current_line:match('^> (.*)') or ''
  
  update_display(query, left_width, right_width)
  vim.api.nvim_win_set_cursor(popup_win, {1, #current_line})
end

-- Function to create and show popup
function M.show()
  -- Get editor dimensions
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Calculate column widths (40% left, 60% right)
  local left_width = math.floor(width * 0.4)
  local right_width = width - left_width - 3  -- 3 for separator " │ "
  
  -- Create buffer
  popup_buf = vim.api.nvim_create_buf(false, true)
  
  -- Create window
  popup_win = vim.api.nvim_open_win(popup_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Fuzzy Finder ',
    title_pos = 'center',
  })
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(popup_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(popup_buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(popup_buf, 'modifiable', true)
  
  -- Initial search (empty query shows all files)
  results = search_files('')
  selected_idx = 1
  
  update_display('', left_width, right_width)
  
  -- Set cursor to end of search line
  vim.api.nvim_win_set_cursor(popup_win, {1, 2})
  
  -- Enter insert mode
  vim.cmd('startinsert')
  
  -- Set up keymaps
  local opts = { buffer = popup_buf, silent = true, nowait = true }
  
  vim.keymap.set('i', '<CR>', function()
    vim.cmd('stopinsert')
    open_file()
  end, opts)
  
  vim.keymap.set('n', '<CR>', open_file, opts)
  vim.keymap.set('n', '<Esc>', close_popup, opts)
  vim.keymap.set('i', '<Esc>', function()
    vim.cmd('stopinsert')
    close_popup()
  end, opts)
  
  vim.keymap.set('i', '<C-n>', function()
    move_selection(1, left_width, right_width)
  end, opts)
  
  vim.keymap.set('i', '<C-p>', function()
    move_selection(-1, left_width, right_width)
  end, opts)
  
  vim.keymap.set('n', '<C-n>', function()
    move_selection(1, left_width, right_width)
  end, opts)
  
  vim.keymap.set('n', '<C-p>', function()
    move_selection(-1, left_width, right_width)
  end, opts)
  
  vim.keymap.set('n', 'j', function()
    move_selection(1, left_width, right_width)
  end, opts)
  
  vim.keymap.set('n', 'k', function()
    move_selection(-1, left_width, right_width)
  end, opts)
  
  vim.keymap.set('i', '<C-c>', function()
    vim.cmd('stopinsert')
    close_popup()
  end, opts)
  
  -- Set up autocmd for text changes
  vim.api.nvim_create_autocmd({'TextChangedI', 'TextChanged'}, {
    buffer = popup_buf,
    callback = function()
      -- Ensure we're always on line 1
      local cursor = vim.api.nvim_win_get_cursor(popup_win)
      if cursor[1] ~= 1 then
        vim.api.nvim_win_set_cursor(popup_win, {1, cursor[2]})
      end
      on_search_change(left_width, right_width)
    end,
  })
  
  -- Prevent moving to other lines
  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = popup_buf,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(popup_win)
      if cursor[1] ~= 1 then
        vim.api.nvim_win_set_cursor(popup_win, {1, cursor[2]})
      end
    end,
  })
end

return M
