-- plugin/init.lua
-- Git Changes Plugin for Neovim
-- Shows git diff changes in the sign column and git blame on hover

local M = {}

--log = require('plugin.log')
--log:write('Starting')
-- Plugin state
M.config = {
  signs = {
    add = { text = '+', hl = 'GitSignsAdd' },
    change = { text = '~', hl = 'GitSignsChange' },
    delete = { text = '_', hl = 'GitSignsDelete' },
  },
  enabled = true,
  debounce_ms = 200,
  blame_enabled = true,
  blame_delay_ms = 500,
}

M.buffers = {}
local ns_id = vim.api.nvim_create_namespace('git_changes')
local blame_ns_id = vim.api.nvim_create_namespace('git_blame')
local blame_timer = nil
local last_blame_line = nil

-- Setup function to be called by user
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
  
  -- Define highlight groups
  vim.api.nvim_set_hl(0, 'GitSignsAdd', { fg = '#98c379', default = true })
  vim.api.nvim_set_hl(0, 'GitSignsChange', { fg = '#e5c07b', default = true })
  vim.api.nvim_set_hl(0, 'GitSignsDelete', { fg = '#e06c75', default = true })
  vim.api.nvim_set_hl(0, 'GitBlame', { fg = '#7c7c7c', italic = true, default = true })
  
  -- Setup autocommands
  local group = vim.api.nvim_create_augroup('GitChanges', { clear = true })
  
  vim.api.nvim_create_autocmd({'BufEnter', 'BufWritePost', 'BufReadPost'}, {
   group = group,
    callback = function(args)
      M.attach_to_buffer(args.buf)
    end,
  })
  
  vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
    group = group,
    callback = function(args)
      M.schedule_update(args.buf)
    end,
  })
  
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = group,
    callback = function(args)
      M.schedule_blame(args.buf)
    end,
  })
  
  vim.api.nvim_create_autocmd('CursorMovedI', {
    group = group,
    callback = function(args)
      M.clear_blame(args.buf)
    end,
  })
  
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function(args)
      M.detach_from_buffer(args.buf)
    end,
  })
  
  -- Create commands
  vim.api.nvim_create_user_command('GitChangesToggle', function()
    M.toggle()
  end, {})
  
  vim.api.nvim_create_user_command('GitChangesRefresh', function()
    M.refresh_all()
  end, {})
  
  vim.api.nvim_create_user_command('GitBlameToggle', function()
    M.toggle_blame()
  end, {})
end

-- Check if buffer is in a git repo
function M.is_git_repo(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == '' then return false end
  
  local dir = vim.fn.fnamemodify(file, ':h')
  local result = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(dir) .. ' rev-parse --git-dir 2>/dev/null')
  
  return vim.v.shell_error == 0 and #result > 0
end

-- Get git diff for a file
function M.get_git_diff(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == '' then return nil end
  
  -- Get diff from git
  local cmd = string.format('git -C %s diff HEAD -- %s', 
    vim.fn.shellescape(vim.fn.fnamemodify(file, ':h')),
    vim.fn.shellescape(vim.fn.fnamemodify(file, ':t')))
  
  local result = vim.fn.systemlist(cmd)
  
  if vim.v.shell_error ~= 0 then
    -- Try against index if file is not yet committed
    cmd = string.format('git -C %s diff -- %s', 
      vim.fn.shellescape(vim.fn.fnamemodify(file, ':h')),
      vim.fn.shellescape(vim.fn.fnamemodify(file, ':t')))
    result = vim.fn.systemlist(cmd)
  end
  
  return result
end

-- Parse git diff output
function M.parse_diff(diff_output)
  local changes = {}
  local current_line = 0
  
  for _, line in ipairs(diff_output) do
    if line:match('^@@') then
      -- Parse hunk header: @@ -old_start,old_count +new_start,new_count @@
      local new_start, new_count = line:match('%+(%d+),?(%d*)')
      current_line = tonumber(new_start) or 0
    elseif line:match('^%+') and not line:match('^%+%+%+') then
      -- Added line
      table.insert(changes, { line = current_line, type = 'add' })
      current_line = current_line + 1
    elseif line:match('^%-') and not line:match('^%-%-%-') then
      -- Deleted line
      table.insert(changes, { line = current_line, type = 'delete' })
      -- Don't increment current_line for deletions
    elseif not line:match('^\\') then
      -- Context line or modified
      if current_line > 0 then
        current_line = current_line + 1
      end
    end
  end
  
  return changes
end

-- Apply signs to buffer
function M.apply_signs(bufnr, changes)
  -- Clear existing signs
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  
  local processed = {}
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  
  for _, change in ipairs(changes) do
    if change.line > 0 and not processed[change.line] then
      processed[change.line] = true
      
      -- Check if line is within buffer bounds
      if change.line <= line_count then
        local sign_config = M.config.signs[change.type]
        if sign_config then
          -- Use pcall to safely set extmark
          pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, change.line - 1, 0, {
            sign_text = sign_config.text,
            sign_hl_group = sign_config.hl,
            priority = 100,
          })
        end
      end
    end
  end
end

-- Update buffer signs
function M.update_buffer(bufnr)
  if not M.config.enabled then return end
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  if not M.is_git_repo(bufnr) then return end
  
  local diff = M.get_git_diff(bufnr)
  if not diff or #diff == 0 then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    return
  end
  
  local changes = M.parse_diff(diff)
  M.apply_signs(bufnr, changes)
end

-- Schedule update with debounce
function M.schedule_update(bufnr)
  local buf_state = M.buffers[bufnr]
  if not buf_state then 
    M.attach_to_buffer(bufnr)
    buf_state = M.buffers[bufnr]
    if not buf_state then return end
  end
  
  if buf_state.timer then
    vim.fn.timer_stop(buf_state.timer)
  end
  
  buf_state.timer = vim.fn.timer_start(M.config.debounce_ms, function()
    M.update_buffer(bufnr)
    buf_state.timer = nil
  end)
end

-- Get git blame for a specific line
function M.get_git_blame(bufnr, line_num)
  if not M.config.blame_enabled then return nil end
  
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == '' then return nil end
  
  local cmd = string.format(
    'git -C %s blame -L %d,%d --porcelain -- %s 2>/dev/null',
    vim.fn.shellescape(vim.fn.fnamemodify(file, ':h')),
    line_num,
    line_num,
    vim.fn.shellescape(vim.fn.fnamemodify(file, ':t'))
  )
  
  local result = vim.fn.systemlist(cmd)
  
  if vim.v.shell_error ~= 0 or #result == 0 then
    return nil
  end
  
  -- Parse porcelain format
  local blame_info = {}
  for _, line in ipairs(result) do
    if line:match('^author ') then
      blame_info.author = line:gsub('^author ', '')
    elseif line:match('^author%-time ') then
--      log:write("line " .. line)
      local time_str = line:gsub('^author%-time ', '')
      local timestamp = tonumber(time_str)
      if timestamp then
        blame_info.time = os.date('%Y-%m-%d', timestamp)
      end
    elseif line:match('^summary ') then
      blame_info.summary = line:gsub('^summary ', '')
    end
  end
  
  if blame_info.author and blame_info.time then
    return string.format('%s, %s: %s', 
      blame_info.author, 
      blame_info.time,
      blame_info.summary or '')
  end
  
  return nil
end

-- Clear blame virtual text
function M.clear_blame(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, blame_ns_id, 0, -1)
  end
  last_blame_line = nil
end

-- Show blame for current line
function M.show_blame(bufnr)
  if not M.config.blame_enabled then return end
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  if not M.is_git_repo(bufnr) then return end
  
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  
  -- Don't update if we're on the same line
  if last_blame_line == line_num then
    return
  end
  
  -- Clear previous blame
  M.clear_blame(bufnr)
  last_blame_line = line_num
  
  local blame_text = M.get_git_blame(bufnr, line_num)
  
  if blame_text then
    pcall(vim.api.nvim_buf_set_extmark, bufnr, blame_ns_id, line_num - 1, 0, {
      virt_text = {{ '  ' .. blame_text, 'GitBlame' }},
      virt_text_pos = 'eol',
      priority = 50,
    })
  end
end

-- Schedule blame with delay
function M.schedule_blame(bufnr)
  if not M.config.blame_enabled then return end
  
  -- Cancel existing timer
  if blame_timer then
    vim.fn.timer_stop(blame_timer)
    blame_timer = nil
  end
  
  -- Schedule new blame update
  blame_timer = vim.fn.timer_start(M.config.blame_delay_ms, function()
    M.show_blame(bufnr)
    blame_timer = nil
  end)
end

-- Attach to buffer
function M.attach_to_buffer(bufnr)
  if M.buffers[bufnr] then return end
  if not M.is_git_repo(bufnr) then return end
  
  M.buffers[bufnr] = { timer = nil }
  M.update_buffer(bufnr)
end

-- Detach from buffer
function M.detach_from_buffer(bufnr)
  local buf_state = M.buffers[bufnr]
  if buf_state and buf_state.timer then
    vim.fn.timer_stop(buf_state.timer)
  end
  M.buffers[bufnr] = nil
  M.clear_blame(bufnr)
end

-- Toggle plugin
function M.toggle()
  M.config.enabled = not M.config.enabled
  
  if M.config.enabled then
    print('Git changes: enabled')
    M.refresh_all()
  else
    print('Git changes: disabled')
    for bufnr, _ in pairs(M.buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      end
    end
  end
end

-- Toggle blame
function M.toggle_blame()
  M.config.blame_enabled = not M.config.blame_enabled
  
  if M.config.blame_enabled then
    print('Git blame: enabled')
  else
    print('Git blame: disabled')
    for bufnr, _ in pairs(M.buffers) do
      M.clear_blame(bufnr)
    end
  end
end

-- Refresh all buffers
function M.refresh_all()
  for bufnr, _ in pairs(M.buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      M.update_buffer(bufnr)
    end
  end
end

return M
