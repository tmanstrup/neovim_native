-- diff_lcs.nvim — FULL ENHANCED VERSION
-- Features:
-- 1. Gutter signs (+, -, M)
-- 2. Inline custom highlights
-- 3. Toggle commands :LcsDiffEnable / :LcsDiffDisable
-- 4. Git revision override :LcsDiffRev <rev>
-- 5. Popup diff window that follows the cursor
-- 6. Updates every 100 ms only in Insert mode

local M = {}

log = require('plugin.log')
log:write('Starting') -- Just to show how it's called

-- STATE
M.enabled = true
M.revision = "HEAD" -- default revision
M.timer = vim.loop.new_timer()
M.follow_win = nil
M.follow_buf = nil

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
-- Split into lines
--------------------------------------------------------------
local function split_lines(s)
	local t = {}
-- Correct, safe Lua pattern for splitting on newline
	for line in s:gmatch("([^\n]*)\n?") do
		table.insert(t, line)
	end
	return t
end
--	return t
--	end

--------------------------------------------------------------
-- LCS diff
--------------------------------------------------------------
local function compute_lcs(a, b)
    local n, m = #a, #b
    local L = {}
    for i = 0, n do
        L[i] = {}
        for j = 0, m do
            L[i][j] = 0
        end
    end
    for i = 1, n do
        for j = 1, m do
            if a[i] == b[j] then
                L[i][j] = L[i-1][j-1] + 1
            else
                L[i][j] = math.max(L[i-1][j], L[i][j-1])
            end
        end
    end
    return L
end

local function backtrack(L, a, b)
    local ops = {}
    local i, j = #a, #b
    while i > 0 or j > 0 do
        if i > 0 and j > 0 and a[i] == b[j] then
            table.insert(ops, 1, { type = "equal", old = i, new = j, line = a[i] })
            i = i - 1
            j = j - 1
        elseif j > 0 and (i == 0 or L[i][j-1] >= L[i-1][j]) then
            table.insert(ops, 1, { type = "added", new = j, line = b[j] })
            j = j - 1
        else
            table.insert(ops, 1, { type = "deleted", old = i, line = a[i] })
            i = i - 1
        end
    end
    return ops
end

local function compute_diff(old_lines, new_lines)
    local L = compute_lcs(old_lines, new_lines)
    local diff = backtrack(L, old_lines, new_lines)
--	log:write('diff size:' .. #diff)
    -- Merge delete+add => modified
    local i = 1
    while i <= #diff do
        if diff[i].type == "deleted" and diff[i+1] and diff[i+1].type == "added" then
            diff[i].type = "modified"
            diff[i].newline = diff[i+1].line
            diff[i].new = diff[i+1].new
			log:write('modify:' .. diff[i+1].line)
			table.remove(diff, i+1)
        else
			log:write('unknow:' .. diff[i].line .. ' ' .. diff[i].type)
            i = i + 1
        end
    end
    return diff
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
	log:write('l:'..line .. ' t:' .. type)
    if name then
		log:write('lcs:'..name .. ' l:' .. line)
        vim.fn.sign_place(0, "lcs", name, bufnr, { lnum = line, priority = 10 })
    end
end

--------------------------------------------------------------
-- INLINE HIGHLIGHTS
--------------------------------------------------------------
local function apply_inline_highlights(bufnr, diff)
    vim.api.nvim_buf_clear_namespace(bufnr, 2025, 0, -1)

    for _, d in ipairs(diff) do
        if d.type == "added" and d.new then
            vim.api.nvim_buf_add_highlight(bufnr, 2025, "LcsAdd", d.new - 1, 0, -1)

        elseif d.type == "deleted" and d.old then
            -- Cannot highlight deleted lines — not in buffer

        elseif d.type == "modified" and d.new then
            vim.api.nvim_buf_add_highlight(bufnr, 2025, "LcsModify", d.new - 1, 0, -1)
        end
    end
end

--------------------------------------------------------------
-- POPUP WINDOW THAT FOLLOWS CURSOR
--------------------------------------------------------------
local function update_floating(diff)
    if not M.follow_buf or not vim.api.nvim_buf_is_valid(M.follow_buf) then
        M.follow_buf = vim.api.nvim_create_buf(false, true)
    end

    local lines = {}
    for _, d in ipairs(diff) do
        if d.type == "added" then table.insert(lines, "+  " .. d.line) end
        if d.type == "deleted" then table.insert(lines, "-  " .. d.line) end
        if d.type == "modified" then table.insert(lines, "M  " .. d.line .. " -> " .. d.newline) end
    end

    vim.api.nvim_buf_set_lines(M.follow_buf, 0, -1, false, lines)

    local pos = vim.api.nvim_win_get_cursor(0)
    local row = pos[1]

--    if not M.follow_win or not vim.api.nvim_win_is_valid(M.follow_win) then
--        M.follow_win = vim.api.nvim_open_win(M.follow_buf, false, {
--            relative = "cursor",
--            row = 1,
--            col = 4,
--            width = 60,
--            height = math.min(#lines, 10),
--            style = "minimal",
--            border = "rounded",
--        })
--    else
--        vim.api.nvim_win_set_config(M.follow_win, {
--            relative = "cursor",
--            row = 1,
--            col = 4,
--            width = 60,
--            height = math.min(#lines, 10),
--            style = "minimal",
--            border = "rounded",
--        })
--    end
end

--------------------------------------------------------------
-- MAIN UPDATE LOOP
--------------------------------------------------------------
local function update()
--    if not M.enabled then return end
    if vim.fn.mode() ~= "i" then return end
    local bufnr = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(bufnr)
    if file == "" then return end

    -- Read git version
	local realname = vim.fs.basename(file)
    local git_data = shell("git show " .. M.revision .. ":" .. vim.fn.fnameescape(realname))
    if git_data == "" then 
		log:write('no git data: git show ' .. M.revision .. ":" .. vim.fn.fnameescape(realname))
		return
	end

    local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local buf_text = table.concat(buf_lines, "")

    local old_lines = split_lines(git_data)
    local new_lines = split_lines(buf_text)
--	log:write('o:' .. #old_lines .. ' n:' .. #new_lines)
    local diff = compute_diff(old_lines, new_lines)

    -- Apply gutter signs
    clear_signs(bufnr)
    for _, d in ipairs(diff) do
		if d.new then 
			log:write('new:' ..d.new)
			place_sign(bufnr, d.new, d.type) end
        if d.type == "deleted" and d.old then 
			log:write('old:' ..d.old)
			place_sign(bufnr, d.old, d.type) end
    end

    -- Inline highlights
--    apply_inline_highlights(bufnr, diff)

    -- Floating window
--    update_floating(diff)
end

--------------------------------------------------------------
-- START/STOP
--------------------------------------------------------------
function M.enable()
    M.enabled = true
end

function M.disable()
    M.enabled = false
    clear_signs(vim.api.nvim_get_current_buf())
end

function M.set_revision(rev)
    M.revision = rev
end

--------------------------------------------------------------
-- COMMANDS
--------------------------------------------------------------
vim.api.nvim_create_user_command("LcsDiffEnable", function() M.enable() end, {})
vim.api.nvim_create_user_command("LcsDiffDisable", function() M.disable() end, {})
vim.api.nvim_create_user_command("LcsDiffRev", function(opts) M.set_revision(opts.args) end, { nargs = 1 })

--------------------------------------------------------------
-- AUTO START TIMER
--------------------------------------------------------------
-- AUTOCMD: Trigger on TextChangedI
--vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
--callback = function()
--	print("update")
--	vim.schedule(update)
--end,
--})

M.timer:start(0, 300, vim.schedule_wrap(update))

return M
