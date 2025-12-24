local M = {}

-- Simple function to show that something occurred
local function notify(msg)
  vim.api.nvim_echo({{msg, "WarningMsg"}}, false, {})
end

----------------------------------------------------------
-- 1. Autocmd method (TextChanged / TextChangedI)
----------------------------------------------------------
function M.setup_autocmd()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = vim.api.nvim_create_augroup("TextWatcherAutocmd", { clear = true }),
    callback = function(ev)
      notify("Text changed in buffer " .. ev.buf)
    end,
  })
end

----------------------------------------------------------
-- 2. on_lines method (nvim_buf_attach)
----------------------------------------------------------
function M.attach_to_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, byte_count)
      notify(
        string.format(
          "on_lines: buf=%d  tick=%d  lines %d..%d → %d",
          buf, changedtick, firstline, lastline, new_lastline
        )
      )
    end,

    on_detach = function()
      notify("Detached from buffer")
    end,
  })

  notify("Attached to buffer " .. bufnr)
end

----------------------------------------------------------
-- Plugin setup
----------------------------------------------------------
function M.setup(opts)
  opts = opts or {}

  -- Enable simple autocmd watcher if requested
  if opts.autocmd ~= false then
    M.setup_autocmd()
  end

  -- Attach to current buffer if requested
  if opts.attach then
    M.attach_to_buffer(opts.attach_bufnr)
  end
end

return M

