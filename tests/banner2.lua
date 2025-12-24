-- bufbanner.nvim - Display open buffers as a banner at the top
local M = {}

local namespace = vim.api.nvim_create_namespace('buffer_banner')
local banner_bufnr = nil
local banner_winid = nil

-- Configuration
local config = {
  height = 1,
  separator = ' | ',
  current_buf_hl = 'TabLineSel',
  other_buf_hl = 'TabLine',
  modified_indicator = '[+]',
}

-- Get list of valid buffers
local function get_buffers()
  local bufs = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted then
      local name = vim.api.nvim_buf_get_name(bufnr)
      local filename = vim.fn.fnamemodify(name, ':t')
      if filename == '' then
        filename = '[No Name]'
      end
      
      local modified = vim.bo[bufnr].modified and config.modified_indicator or ''
      
      table.insert(bufs, {
        bufnr = bufnr,
        name = filename .. modified,
        is_current = bufnr == vim.api.nvim_get_current_buf()
      })
    end
  end
  return bufs
end

-- Create banner text with highlighting
local function create_banner_content()
  local bufs = get_buffers()
  local parts = {}
  local highlights = {}
  local col = 0
  
  for i, buf in ipairs(bufs) do
    local text = buf.name
    local hl = buf.is_current and config.current_buf_hl or config.other_buf_hl
    
    table.insert(highlights, {
      hl_group = hl,
      col_start = col,
      col_end = col + #text
    })
    
    table.insert(parts, text)
    col = col + #text
    
    if i < #bufs then
      table.insert(parts, config.separator)
      col = col + #config.separator
    end
  end
  
  return table.concat(parts, ''), highlights
end

-- Update banner display
local function update_banner()
  if not banner_bufnr or not vim.api.nvim_buf_is_valid(banner_bufnr) then
    return
  end
  
  local content, highlights = create_banner_content()
  
  -- Temporarily make buffer modifiable
  vim.bo[banner_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(banner_bufnr, 0, -1, false, {content})
  vim.bo[banner_bufnr].modifiable = false
  
  -- Clear old highlights
  vim.api.nvim_buf_clear_namespace(banner_bufnr, namespace, 0, -1)
  
  -- Apply new highlights
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(
      banner_bufnr,
      namespace,
      hl.hl_group,
      0,
      hl.col_start,
      hl.col_end
    )
  end
end

-- Create the banner window
local function create_banner()
  -- Create buffer
  banner_bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[banner_bufnr].bufhidden = 'wipe'
  vim.bo[banner_bufnr].buftype = 'nofile'
  vim.bo[banner_bufnr].swapfile = false
  vim.bo[banner_bufnr].modifiable = false
  
  -- Create window at top
  banner_winid = vim.api.nvim_open_win(banner_bufnr, false, {
    relative = 'editor',
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = config.height,
    style = 'minimal',
    focusable = false,
    zindex = 1000,
  })
  
  vim.wo[banner_winid].winhighlight = 'Normal:TabLineFill'
  
  update_banner()
end

-- Resize banner on VimResized
local function resize_banner()
  if banner_winid and vim.api.nvim_win_is_valid(banner_winid) then
    vim.api.nvim_win_set_width(banner_winid, vim.o.columns)
  end
end

-- Setup function
function M.setup(opts)
  config = vim.tbl_extend('force', config, opts or {})
  
  -- Create banner
  create_banner()
  
  -- Auto-update on buffer events
  local group = vim.api.nvim_create_augroup('BufferBanner', { clear = true })
  
  vim.api.nvim_create_autocmd({
    'BufAdd', 'BufDelete', 'BufEnter', 'BufModifiedSet'
  }, {
    group = group,
    callback = update_banner
  })
  
  vim.api.nvim_create_autocmd('VimResized', {
    group = group,
    callback = resize_banner
  })
end

-- Toggle banner visibility
function M.toggle()
  if banner_winid and vim.api.nvim_win_is_valid(banner_winid) then
    vim.api.nvim_win_close(banner_winid, true)
    banner_winid = nil
  else
    create_banner()
  end
end

return M
