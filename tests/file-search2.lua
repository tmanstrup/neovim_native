-- plugin/file-search.lua
local M = {}

-- Configuration
M.config = {
  results_height = 15,  -- Height of results window in lines
  search_height = 8,    -- Height of search window in lines
  default_path = vim.fn.getcwd(),
  ignore_patterns = { ".git", "node_modules", ".cache" },
  keymap = "<leader>fs"
}

-- State
local search_buf = nil
local results_buf = nil
local search_win = nil
local results_win = nil

-- Function to create horizontal split window
local function create_split_win(buf, height, position, title)
  -- Save current window
  local current_win = vim.api.nvim_get_current_win()
  
  -- Create split based on position
  if position == "top" then
    vim.cmd("topleft split")
  else
    vim.cmd("botright split")
  end
  
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_height(win, height)
  
  -- Set window options
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false
  
  -- Add title as a virtual text in the first line if possible
  if title then
    vim.api.nvim_buf_set_name(buf, title)
  end
  
  return win
end

-- Function to search files
local function search_files(pattern, path)
  local results = {}
  local ignore_pattern = table.concat(M.config.ignore_patterns, "|")
  
  -- Use ripgrep if available, otherwise fall back to grep
  local cmd
  if vim.fn.executable("rg") == 1 then
    cmd = string.format(
      "rg --line-number --with-filename --no-heading --color=never '%s' '%s' 2>/dev/null",
      pattern:gsub("'", "'\\''"),
      path
    )
  else
    cmd = string.format(
      "grep -rn '%s' '%s' 2>/dev/null | grep -Ev '%s'",
      pattern:gsub("'", "'\\''"),
      path,
      ignore_pattern
    )
  end

  local handle = io.popen(cmd)
  if handle then
    for line in handle:lines() do
      table.insert(results, line)
    end
    handle:close()
  end

  return results
end

-- Function to display results
local function display_results(results)
  if not results_buf or not vim.api.nvim_buf_is_valid(results_buf) then
    results_buf = vim.api.nvim_create_buf(false, true)
  end

  -- Set buffer options
  vim.api.nvim_buf_set_option(results_buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(results_buf, "filetype", "search-results")
  vim.api.nvim_buf_set_option(results_buf, "modifiable", false)

  -- Prepare content
  local lines = {}
  if #results == 0 then
    lines = { "No results found." }
  else
    table.insert(lines, string.format("═══ Found %d results ═══", #results))
    table.insert(lines, "")
    for _, result in ipairs(results) do
      table.insert(lines, result)
    end
  end

  -- Set content
  vim.api.nvim_buf_set_option(results_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(results_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(results_buf, "modifiable", false)

  -- Create or update window
  if not results_win or not vim.api.nvim_win_is_valid(results_win) then
    results_win = create_split_win(results_buf, M.config.results_height, "top", " Search Results ")
  end

  -- Set keymaps for results window
  local opts = { buffer = results_buf, noremap = true, silent = true }
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    local file, line_num = line:match("^([^:]+):(%d+)")
    if file and line_num then
      -- Close windows
      if vim.api.nvim_win_is_valid(results_win) then
        vim.api.nvim_win_close(results_win, true)
      end
      if search_win and vim.api.nvim_win_is_valid(search_win) then
        vim.api.nvim_win_close(search_win, true)
      end
      -- Open file
      vim.cmd("edit " .. file)
      vim.api.nvim_win_set_cursor(0, { tonumber(line_num), 0 })
    end
  end, opts)

  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(results_win) then
      vim.api.nvim_win_close(results_win, true)
    end
    if search_win and vim.api.nvim_win_is_valid(search_win) then
      vim.api.nvim_win_close(search_win, true)
    end
  end, opts)

  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(results_win) then
      vim.api.nvim_win_close(results_win, true)
    end
    if search_win and vim.api.nvim_win_is_valid(search_win) then
      vim.api.nvim_win_close(search_win, true)
    end
  end, opts)

  -- Add syntax highlighting
  vim.cmd([[
    syntax match SearchResultFile "^[^:]*" contained
    syntax match SearchResultLineNr ":\d\+:" contained
    syntax match SearchResultLine "^.*$" contains=SearchResultFile,SearchResultLineNr
    highlight link SearchResultFile Directory
    highlight link SearchResultLineNr LineNr
  ]])
end

-- Function to perform search
local function perform_search()
  if not search_buf or not vim.api.nvim_buf_is_valid(search_buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(search_buf, 0, -1, false)
  local pattern = lines[1] or ""
  local path = lines[2] or M.config.default_path

  if pattern == "" then
    vim.notify("Please enter a search pattern", vim.log.levels.WARN)
    return
  end

  vim.notify("Searching...", vim.log.levels.INFO)
  local results = search_files(pattern, path)
  display_results(results)
  
  -- Focus back on search window after displaying results
  if search_win and vim.api.nvim_win_is_valid(search_win) then
    vim.api.nvim_set_current_win(search_win)
  end
end

-- Function to open search interface
function M.open_search()
  -- Get the root path of current folder
  local root_path = vim.fn.getcwd()
  
  -- Create search buffer
  search_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(search_buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(search_buf, "buftype", "nofile")

  -- Set initial content with root path
  local initial_lines = {
    "",
    root_path,
    "",
    "─────────────────────────────────────",
    "Press <CR> to search, <Esc> or q to cancel"
  }
  vim.api.nvim_buf_set_lines(search_buf, 0, -1, false, initial_lines)

  -- Create window at bottom
  search_win = create_split_win(search_buf, M.config.search_height, "bottom", " File Search ")

  -- Set cursor to first line
  vim.api.nvim_win_set_cursor(search_win, { 1, 0 })

  -- Set keymaps
  local opts = { buffer = search_buf, noremap = true, silent = true }
  vim.keymap.set("n", "<CR>", perform_search, opts)
  vim.keymap.set("i", "<CR>", function()
    vim.cmd("stopinsert")
    perform_search()
  end, opts)
  
  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(search_win) then
      vim.api.nvim_win_close(search_win, true)
    end
    if results_win and vim.api.nvim_win_is_valid(results_win) then
      vim.api.nvim_win_close(results_win, true)
    end
  end, opts)
  
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(search_win) then
      vim.api.nvim_win_close(search_win, true)
    end
    if results_win and vim.api.nvim_win_is_valid(results_win) then
      vim.api.nvim_win_close(results_win, true)
    end
  end, opts)

  -- Enter insert mode on first line
  vim.cmd("startinsert")
end

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  -- Register command
  vim.api.nvim_create_user_command("FileSearch", M.open_search, {})
  
  -- Set default keymap
  vim.keymap.set("n", M.config.keymap, M.open_search, { 
    noremap = true, 
    silent = true,
    desc = "Open file search"
  })
end

return M
