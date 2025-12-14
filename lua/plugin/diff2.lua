-- diff_lcs.nvim – GIT DIFF VERSION
-- Features:
-- 1. Gutter signs (+, -, M)
-- 2. Inline custom highlights
-- 3. Toggle commands :LcsDiffEnable / :LcsDiffDisable
-- 4. Git revision override :LcsDiffRev <rev>
-- 5. Uses git diff --patch-with-raw for change detection
-- 6. Updates every 300 ms only in Insert mode

local M = {}

log = require('plugin.log')
log:write('Starting')

-- STATE
M.enabled = true
M.revision = "HEAD"
M.timer = vim.loop.new_timer()
M.follow_win = nil
M.follow_buf = nil
M.show_virtual_text = true

--------------------------------------------------------------
-- Shell helper
--------------------------------------------------------------
local function shell(cmd)
    local f = io.popen(cmd .. " 2>/dev/null")
    if not f then return "" end
    local out = f:read("*a")
    f:close()
    return out
end

--------------------------------------------------------------
-- CUSTOM HIGHLIGHTS
--------------------------------------------------------------
vim.api.nvim_set_hl(0, "LcsAdd", { fg = "#00FF00", bg = "#003000" })
vim.api.nvim_set_hl(0, "LcsDelete", { fg = "#FF5555", bg = "#300000" })
vim.api.nvim_set_hl(0, "LcsModify", { fg = "#FFFF00", bg = "#303000" })

--------------------------------------------------------------
-- GUTTER SIGNS
--------------------------------------------------------------
vim.fn.sign_define("LcsSignAdd", { text = "+", texthl = "LcsAdd" })
vim.fn.sign_define("LcsSignDelete", { text = "-", texthl = "LcsDelete" })
vim.fn.sign_define("LcsSignModify", { text = "M", texthl = "LcsModify" })

local function clear_signs(bufnr)
    vim.fn.sign_unplace("lcs", { buffer = bufnr })
end

local function place_sign(bufnr, line, type)
    local name = ({
        added = "LcsSignAdd",
        deleted = "LcsSignDelete",
        modified = "LcsSignModify",
    })[type]
    
    if not name then
        return
    end
    
    -- Get buffer line count to validate
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    
    -- Ensure line is within valid range
    if line < 1 then
        line = 1
    elseif line > line_count then
        line = line_count
    end
    
    -- Don't place signs if buffer is empty
    if line_count == 0 or line < 1 then
        log:write('Cannot place sign: buffer empty or invalid line ' .. line)
        return
    end
    
    log:write('Placing sign: ' .. name .. ' at line ' .. line)
    
    -- Use pcall to catch any errors
    local ok, err = pcall(vim.fn.sign_place, 0, "lcs", name, bufnr, { lnum = line, priority = 10 })
    if not ok then
        log:write('Failed to place sign: ' .. tostring(err))
    end
end

--------------------------------------------------------------
-- VIRTUAL TEXT FOR DELETED LINES
--------------------------------------------------------------
local function show_deleted_lines(bufnr, changes)
    -- Clear existing virtual text
    vim.api.nvim_buf_clear_namespace(bufnr, 2026, 0, -1)
    
    if not M.show_virtual_text then
        return
    end
    
    -- Get buffer line count
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    
    for _, change in ipairs(changes) do
        if change.type == "deleted" and change.new and change.line then
            -- Show deleted content as virtual text below the deletion point
            local display_line = change.new == 0 and 0 or (change.new - 1)
            
            -- Ensure display_line is within valid range
            if display_line < 0 then
                display_line = 0
            elseif display_line >= line_count then
                display_line = math.max(0, line_count - 1)
            end
            
            local virt_text = {
                {"  [deleted] ", "LcsDelete"},
                {change.line, "Comment"}
            }
            
            -- Safely set extmark with error handling
            local ok, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, 2026, display_line, 0, {
                virt_lines = {{virt_text}},
                virt_lines_above = false,
            })
            
            if ok then
                log:write("Virtual text for deletion at line " .. display_line)
            else
                log:write("Failed to set virtual text at line " .. display_line .. ": " .. tostring(err))
            end
        end
    end
end

--------------------------------------------------------------
-- PARSE GIT DIFF OUTPUT
--------------------------------------------------------------
local function parse_git_diff(git_diff_output)
    local changes = {}
    local pending_deletes = {}
    
    -- Parse unified diff format
    -- Look for @@ -old_start,old_count +new_start,new_count @@
    local in_hunk = false
    local new_line = 0
    local old_line = 0
    
    for line in git_diff_output:gmatch("[^\n]+") do
        -- Match hunk header
        local old_start, old_count, new_start, new_count = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
        
        if old_start then
            -- Flush any pending deletes from previous hunk
            for _, del in ipairs(pending_deletes) do
                table.insert(changes, del)
            end
            pending_deletes = {}
            
            in_hunk = true
            old_line = tonumber(old_start)
            new_line = tonumber(new_start)
            old_count = old_count == "" and 1 or tonumber(old_count)
            new_count = new_count == "" and 1 or tonumber(new_count)
            log:write(string.format("Hunk: old=%d,%d new=%d,%d", old_line, old_count, new_line, new_count))
        elseif in_hunk then
            local first_char = line:sub(1, 1)
            local content = line:sub(2)
            
            if first_char == "+" then
                -- Check if we have pending deletes (could be a modification)
                if #pending_deletes > 0 then
                    local del = table.remove(pending_deletes, 1)
                    -- This is a modification
                    table.insert(changes, {
                        type = "modified",
                        old = del.old,
                        new = new_line,
                        line = del.line,
                        newline = content
                    })
                    log:write("Modified line " .. new_line .. ": " .. del.line .. " -> " .. content)
                else
                    -- Pure addition
                    table.insert(changes, {
                        type = "added",
                        new = new_line,
                        line = content
                    })
                    log:write("Added line " .. new_line .. ": " .. content)
                end
                new_line = new_line + 1
                
            elseif first_char == "-" then
                -- Store as pending delete
                table.insert(pending_deletes, {
                    type = "deleted",
                    old = old_line,
                    new = new_line,
                    line = content
                })
                log:write("Pending delete at old line " .. old_line .. ": " .. content)
                old_line = old_line + 1
                
            elseif first_char == " " then
                -- Context line - flush any pending deletes (they are pure deletions)
                for _, del in ipairs(pending_deletes) do
                    table.insert(changes, del)
                    log:write("Flushed delete at line " .. del.new)
                end
                pending_deletes = {}
                
                old_line = old_line + 1
                new_line = new_line + 1
            end
        end
    end
    
    -- Flush remaining pending deletes
    for _, del in ipairs(pending_deletes) do
        table.insert(changes, del)
    end
    
    return changes
end

--------------------------------------------------------------
-- INLINE HIGHLIGHTS
--------------------------------------------------------------
local function apply_inline_highlights(bufnr, changes)
    vim.api.nvim_buf_clear_namespace(bufnr, 2025, 0, -1)

    for _, change in ipairs(changes) do
        if change.type == "added" and change.new then
            vim.api.nvim_buf_add_highlight(bufnr, 2025, "LcsAdd", change.new - 1, 0, -1)
        elseif change.type == "modified" and change.new then
            vim.api.nvim_buf_add_highlight(bufnr, 2025, "LcsModify", change.new - 1, 0, -1)
        end
    end
end

--------------------------------------------------------------
-- MAIN UPDATE LOOP
--------------------------------------------------------------
local function update()
    if not M.enabled then return end
    if vim.fn.mode() ~= "i" then return end
    
    local bufnr = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(bufnr)
    if file == "" then return end

    -- Get current buffer content
    local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local buf_text = table.concat(buf_lines, "\n")
    
    -- Write buffer content to temp file for git diff
    local tmp_file = os.tmpname()
    local f = io.open(tmp_file, "w")
    if not f then
        log:write("Failed to create temp file")
        return
    end
    f:write(buf_text)
    f:close()
    
    -- Get basename for git
    local realname = vim.fs.basename(file)
    
    -- Run git diff with patch format
    local git_cmd = string.format(
        "cd %s && git diff --patch-with-raw --no-color --no-ext-diff %s -- %s",
        vim.fn.shellescape(vim.fn.fnamemodify(file, ":h")),
        M.revision,
        vim.fn.shellescape(realname)
    )
    
    -- Alternative: diff against current working directory file
    -- This compares the buffer content with the git revision
    git_cmd = string.format(
        "cd %s && git show %s:%s | diff -u - %s 2>/dev/null || git diff --no-color --no-ext-diff %s -- %s",
        vim.fn.shellescape(vim.fn.fnamemodify(file, ":h")),
        M.revision,
        vim.fn.shellescape(realname),
        vim.fn.shellescape(tmp_file),
        M.revision,
        vim.fn.shellescape(realname)
    )
    
    -- Better approach: use git diff with stdin
    git_cmd = string.format(
        "cd %s && git diff --no-color --no-ext-diff -U0 %s -- %s %s",
        vim.fn.shellescape(vim.fn.fnamemodify(file, ":h")),
        M.revision,
        vim.fn.shellescape(realname),
        vim.fn.shellescape(tmp_file)
    )
    
    -- Best approach: compare git version with temp file
    git_cmd = string.format(
        "cd %s && git show %s:./%s > /tmp/git_base.tmp 2>/dev/null && diff -U0 /tmp/git_base.tmp %s || true",
        vim.fn.shellescape(vim.fn.fnamemodify(file, ":h")),
        M.revision,
        vim.fn.shellescape(realname),
        vim.fn.shellescape(tmp_file)
    )
    
    log:write("Running: " .. git_cmd)
    local git_data = shell(git_cmd)
    
    -- Clean up temp file
    os.remove(tmp_file)
    
    if git_data == "" then
        log:write("No git diff output (file may be unchanged or not in git)")
        clear_signs(bufnr)
        return
    end
    
    log:write("Git diff output length: " .. #git_data)
    
    -- Parse the diff output
    local changes = parse_git_diff(git_data)
    log:write("Found " .. #changes .. " changes")
    
    -- Get buffer line count for validation
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    
    -- If buffer is empty, only show virtual text for deletions at line 0
    if line_count == 0 or (line_count == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == "") then
        log:write("Buffer is empty, showing only virtual text for deletions")
        show_deleted_lines(bufnr, changes)
        return
    end
    
    -- Apply gutter signs
    clear_signs(bufnr)
    for _, change in ipairs(changes) do
        if change.type == "added" and change.new then
            place_sign(bufnr, change.new, "added")
        elseif change.type == "deleted" and change.new then
            -- For deletions, place sign at the line after which content was deleted
            local sign_line = change.new > 0 and change.new or 1
            place_sign(bufnr, sign_line, "deleted")
        elseif change.type == "modified" and change.new then
            place_sign(bufnr, change.new, "modified")
        end
    end
    
    -- Show deleted lines as virtual text
    show_deleted_lines(bufnr, changes)
    
    -- Inline highlights (optional)
    apply_inline_highlights(bufnr, changes)
end

--------------------------------------------------------------
-- START/STOP
--------------------------------------------------------------
function M.enable()
    M.enabled = true
    log:write("Diff enabled")
end

function M.disable()
    M.enabled = false
    local bufnr = vim.api.nvim_get_current_buf()
    clear_signs(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, 2025, 0, -1) -- Clear highlights
    vim.api.nvim_buf_clear_namespace(bufnr, 2026, 0, -1) -- Clear virtual text
    log:write("Diff disabled")
end

function M.set_revision(rev)
    M.revision = rev
    log:write("Revision set to: " .. rev)
end

--------------------------------------------------------------
-- SHOW DIFF FOR CURRENT LINE IN POPUP
--------------------------------------------------------------
function M.show_line_diff()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local current_line = cursor_pos[1]
    
    local file = vim.api.nvim_buf_get_name(bufnr)
    if file == "" then
        print("No file in current buffer")
        return
    end
    
    -- Get current buffer content
    local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local buf_text = table.concat(buf_lines, "\n")
    
    -- Write to temp file and get diff
    local tmp_file = os.tmpname()
    local f = io.open(tmp_file, "w")
    if not f then return end
    f:write(buf_text)
    f:close()
    
    local realname = vim.fs.basename(file)
    local git_cmd = string.format(
        "cd %s && git show %s:./%s > /tmp/git_base.tmp 2>/dev/null && diff -U0 /tmp/git_base.tmp %s || true",
        vim.fn.shellescape(vim.fn.fnamemodify(file, ":h")),
        M.revision,
        vim.fn.shellescape(realname),
        vim.fn.shellescape(tmp_file)
    )
    
    local git_data = shell(git_cmd)
    os.remove(tmp_file)
    
    if git_data == "" then
        print("No changes found")
        return
    end
    
    local changes = parse_git_diff(git_data)
    
    -- Find change at current line
    local line_change = nil
    for _, change in ipairs(changes) do
        if change.new and change.new == current_line then
            line_change = change
            break
        end
    end
    
    if not line_change then
        print("No changes at line " .. current_line)
        return
    end
    
    -- Create popup content
    local popup_lines = {}
    local highlights = {}
    
    if line_change.type == "added" then
        table.insert(popup_lines, "═══ Added Line ═══")
        table.insert(popup_lines, "")
        table.insert(popup_lines, "+ " .. line_change.line)
        table.insert(highlights, {line = 2, hl = "LcsAdd"})
        
    elseif line_change.type == "deleted" then
        table.insert(popup_lines, "═══ Deleted Line ═══")
        table.insert(popup_lines, "")
        table.insert(popup_lines, "- " .. line_change.line)
        table.insert(highlights, {line = 2, hl = "LcsDelete"})
        
    elseif line_change.type == "modified" then
        table.insert(popup_lines, "═══ Modified Line ═══")
        table.insert(popup_lines, "")
        table.insert(popup_lines, "Old:")
        table.insert(popup_lines, "- " .. line_change.line)
        table.insert(popup_lines, "")
        table.insert(popup_lines, "New:")
        table.insert(popup_lines, "+ " .. line_change.newline)
        table.insert(highlights, {line = 3, hl = "LcsDelete"})
        table.insert(highlights, {line = 6, hl = "LcsAdd"})
    end
    
    -- Create popup buffer
    local popup_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, popup_lines)
    vim.api.nvim_buf_set_option(popup_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(popup_buf, "bufhidden", "wipe")
    
    -- Calculate popup size
    local width = 60
    for _, line in ipairs(popup_lines) do
        width = math.max(width, #line + 4)
    end
    width = math.min(width, 80)
    local height = #popup_lines
    
    -- Get editor dimensions
    local ui = vim.api.nvim_list_uis()[1]
    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - width) / 2)
    
    -- Create floating window
    local popup_win = vim.api.nvim_open_win(popup_buf, true, {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        title = " Line " .. current_line .. " Diff ",
        title_pos = "center",
    })
    
    -- Apply highlights
    for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(popup_buf, -1, hl.hl, hl.line, 0, -1)
    end
    
    -- Close popup on any key press
    vim.api.nvim_buf_set_keymap(popup_buf, "n", "q", ":close<CR>", {noremap = true, silent = true})
    vim.api.nvim_buf_set_keymap(popup_buf, "n", "<Esc>", ":close<CR>", {noremap = true, silent = true})
    vim.api.nvim_buf_set_keymap(popup_buf, "n", "<CR>", ":close<CR>", {noremap = true, silent = true})
    
    -- Auto-close on focus loss
    vim.api.nvim_create_autocmd({"BufLeave", "WinLeave"}, {
        buffer = popup_buf,
        once = true,
        callback = function()
            if vim.api.nvim_win_is_valid(popup_win) then
                vim.api.nvim_win_close(popup_win, true)
            end
        end
    })
end

--------------------------------------------------------------
-- SHOW ALL CHANGES IN SPLIT WINDOW
--------------------------------------------------------------
function M.show_all_changes()
    local bufnr = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(bufnr)
    if file == "" then
        print("No file in current buffer")
        return
    end
    
    -- Get current buffer content
    local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local buf_text = table.concat(buf_lines, "\n")
    
    -- Write to temp file and get diff
    local tmp_file = os.tmpname()
    local f = io.open(tmp_file, "w")
    if not f then return end
    f:write(buf_text)
    f:close()
    
    local realname = vim.fs.basename(file)
    local git_cmd = string.format(
        "cd %s && git show %s:./%s > /tmp/git_base.tmp 2>/dev/null && diff -U0 /tmp/git_base.tmp %s || true",
        vim.fn.shellescape(vim.fn.fnamemodify(file, ":h")),
        M.revision,
        vim.fn.shellescape(realname),
        vim.fn.shellescape(tmp_file)
    )
    
    local git_data = shell(git_cmd)
    os.remove(tmp_file)
    
    if git_data == "" then
        print("No changes found")
        return
    end
    
    local changes = parse_git_diff(git_data)
    
    -- Create split window with all changes
    vim.cmd("new")
    local change_buf = vim.api.nvim_get_current_buf()
    
    local lines = {"=== Changes from " .. M.revision .. " ===", ""}
    for _, change in ipairs(changes) do
        if change.type == "added" then
            table.insert(lines, string.format("[+] Line %d: %s", change.new, change.line))
        elseif change.type == "deleted" then
            table.insert(lines, string.format("[-] Line %d (deleted): %s", change.new, change.line))
        elseif change.type == "modified" then
            table.insert(lines, string.format("[M] Line %d:", change.new))
            table.insert(lines, string.format("    - %s", change.line))
            table.insert(lines, string.format("    + %s", change.newline))
        end
    end
    
    vim.api.nvim_buf_set_lines(change_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(change_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(change_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_name(change_buf, "LCS Diff Changes")
    
    -- Add syntax highlighting
    vim.api.nvim_buf_call(change_buf, function()
        vim.fn.matchadd("LcsAdd", "^\\[+\\].*")
        vim.fn.matchadd("LcsDelete", "^\\[-\\].*")
        vim.fn.matchadd("LcsModify", "^\\[M\\].*")
    end)
end

function M.toggle_virtual_text()
    M.show_virtual_text = not M.show_virtual_text
    if M.show_virtual_text then
        print("Virtual text enabled")
        vim.schedule(update)
    else
        print("Virtual text disabled")
        vim.api.nvim_buf_clear_namespace(vim.api.nvim_get_current_buf(), 2026, 0, -1)
    end
end

--------------------------------------------------------------
-- COMMANDS
--------------------------------------------------------------
vim.api.nvim_create_user_command("LcsDiffEnable", function() M.enable() end, {})
vim.api.nvim_create_user_command("LcsDiffDisable", function() M.disable() end, {})
vim.api.nvim_create_user_command("LcsDiffRev", function(opts) M.set_revision(opts.args) end, { nargs = 1 })
vim.api.nvim_create_user_command("LcsDiffShowDeleted", function() M.show_all_changes() end, {})
vim.api.nvim_create_user_command("LcsDiffToggleVirtual", function() M.toggle_virtual_text() end, {})
vim.api.nvim_create_user_command("LcsDiffShowDiff", function() M.show_line_diff() end, {})

--------------------------------------------------------------
-- AUTO START TIMER
--------------------------------------------------------------
M.timer:start(0, 300, vim.schedule_wrap(update))

return M