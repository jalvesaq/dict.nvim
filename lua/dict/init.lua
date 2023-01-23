local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local M = {}

function M.setup(config)
    M.opts = {
        dict = nil,
        cache_dir = os.getenv('HOME') .. '/.cache/dict.nvim',
        dict_dir = '/usr/share/dictd'
    }

    for k, v in pairs(config) do
        M.opts[k] = v
    end
    M.from_picker = false
    M.wlist = {}
end

function M.start()
    -- Each combination of dictionaries requires its own cache file
    local cache_file = ''
    local diclist = { }
    if M.opts.dict then
        cache_file = M.opts.cache_dir .. '/index_' .. M.opts.dict
        diclist = { M.opts.dict }
    else
        cache_file = M.opts.cache_dir .. '/index'
        local dl = vim.fn.split(vim.fn.glob(M.opts.dict_dir .. '/' .. '*.index'))
        local d = ''
        for _, v in pairs(dl) do
            d = string.gsub(v, '.*/', '')
            d = string.gsub(d, '.index', '')
            table.insert(diclist, d)
            cache_file = cache_file .. '_' .. d
        end
    end

    if vim.fn.isdirectory(M.opts.cache_dir) == 0 then
        vim.fn.mkdir(M.opts.cache_dir, 'p')
    end

    -- Use the cache file if it already exists
    local f = io.open(cache_file, 'r')
    if f then
        for line in f:lines() do
            table.insert(M.wlist, line)
        end
        f:close()
        return true
    end

    -- Create the cache file
    local tmplist = {}
    for _, v in pairs(diclist) do
        f = io.open(M.opts.dict_dir .. '/' .. v .. '.index', 'r')
        if f == nil then
            vim.api.nvim_err_writeln("Could not open '" .. M.opts.dict_dir .. '/' .. v .. "'")
            return false
        end
        for line in f:lines() do
            table.insert(tmplist, line)
        end
        f:close()
    end
    for k, v in pairs(tmplist) do
        tmplist[k] = string.gsub(v, "\t.*", "")
    end

    --- Avoid duplicate items if more than one dictionary is being used
    table.sort(tmplist)
    for i = 1, #tmplist, 1 do
        if i < #tmplist then
            if tmplist[i] ~= tmplist[i+1] then
                table.insert(M.wlist, tmplist[i])
            end
        else
            table.insert(M.wlist, tmplist[i])
        end
    end

    if #M.wlist == 0 then
        vim.api.nvim_err_writeln("Could not fill the list of words")
        return false
    end

    -- Save the cache file
    f = io.open(cache_file, "w")
    if not f then
        vim.api.nvim_err_writeln("Could not open '" .. cache_file .. "' for writing")
        return false
    end
    for _, v in pairs(M.wlist) do
        f:write(v .. "\n")
    end
    f:close()
    return true
end

function M.pick_word(wrd)
    if not M.wlist then
        M.setup({})
    end
    if #M.wlist == 0 then
        if not M.start() then
            return
        end
    end
    pickers.new({default_text = wrd}, {
        finder = finders.new_table {
            results = M.wlist,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry,
                    ordinal = entry,
                }
            end
        },
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if selection and selection.value then
                    M.from_picker = true
                    M.lookup(selection.value)
                end
            end)
            return true
        end,
    }):find()
end

function M.winclosed()
    M.wid = nil
end

local get_cword = function()
    local line = vim.fn.getline('.')
    local cpos = vim.fn.getpos('.')
    if type(line) == "string" then
        local cchar = string.sub(line, cpos[3], cpos[3])
        vim.g.TheCChar = {line, cpos, cchar}
        if cchar == '' or string.match(cchar, "%s") or string.match(cchar, "%p") then
            return nil
        end
        return vim.fn.expand('<cword>')
    end
    return nil
end

function M.replace()
    local wrd = get_cword()
    if wrd then
        vim.api.nvim_win_close(0, false)
        vim.cmd("normal! ciw" .. wrd)
        vim.cmd("stopinsert")
    end
end

function M.lookup(wrd)
    if not M.wlist then
        M.setup({})
    end
    if #M.wlist == 0 then
        if not M.start() then
            return
        end
    end

    if not wrd then
        wrd = get_cword()
        if not wrd then
            return
        end
    end

    local a
    if M.opts.dict then
        a, _ = io.popen("dict -d " .. M.opts.dict .. " '" .. wrd .. "' 2>/dev/null", "r")
    else
        a, _ = io.popen("dict '" .. wrd .. "' 2>/dev/null", "r")
    end
    if not a then
        vim.api.nvim_err_writeln("Error running: " .. "dict '" .. wrd .. "'")
        return
    end
    local output = a:read("*a")
    local suc, ecd, cd
    suc, ecd, cd = a:close()
    if not suc then
        vim.api.nvim_err_writeln("Error running dict: " .. tostring(suc) .. " " .. tostring(ecd) .. " " .. tostring(cd))
        return
    end

    if output == '' then
        if M.from_picker then
            M.from_picker = false
            vim.api.nvim_echo({{"dictd: no definitions found for "}, {wrd, "Identifier"}}, false, {})
        else
            M.pick_word(wrd)
        end
        return
    end
    M.from_picker = false

    -- Pad space on the left
    output = string.gsub(output, "\n", "\n ")
    -- Minor improvement to WordNet
    output = string.gsub(output, "\n       ([a-z]+) 1: ", "\n     %1\n       1: ")
    -- Mark end of definition with non-separable space
    output = string.gsub(output, "\n \n From ", "\n \n From ")
    -- Mark beginning of pronunciation in Gcide
    output = string.gsub(output, "\\ %(", "\\ (")

    local outlines = vim.fn.split("\n" .. output, "\n")

    if not M.b then
        M.b = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(M.b, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(M.b, 'bufhidden', 'hide')
        vim.api.nvim_buf_set_option(M.b, 'swapfile', false)
        vim.api.nvim_buf_set_option(M.b, 'tabstop', 2)
        vim.api.nvim_buf_set_option(M.b, 'undolevels', -1)
        vim.api.nvim_buf_set_option(M.b, 'syntax', 'dict')
        vim.keymap.set('n', 'q',       ':quit<CR>', {silent = true, buffer  = M.b})
        vim.keymap.set('n', '<Esc>',   ':quit<CR>', {silent = true, buffer  = M.b})
        vim.keymap.set('n', '<Enter>', ':lua require("dict").replace()<CR>', {silent = false, buffer  = M.b})
    end
    vim.api.nvim_buf_set_lines(M.b, 0, -1, true, outlines)

    if not M.wid then
        -- Center the window
        local nc = vim.o.columns
        local fcol = 2
        if nc > 82 then
            fcol = math.floor((nc - 80) / 2)
        end
        local wh = vim.api.nvim_win_get_height(0) - 2
        local fheight
        if wh > #outlines then
            fheight = #outlines
        else
            fheight = wh
        end
        local frow = math.floor((wh - fheight) / 2)

        local opts = {
            relative = 'win',
            width = 80,
            height = fheight,
            col = fcol,
            row = frow,
            anchor = 'NW',
            style = 'minimal',
            -- TODO: get the border from telescope
            border = {
                {"╭", "Normal"}, {"─", "Normal"}, {"╮", "Normal"}, {"│", "Normal"},
                {"╯", "Normal"}, {"─", "Normal"}, {"╰", "Normal"}, {"│", "Normal"}},
                noautocmd = true
            }
        M.wid = vim.api.nvim_open_win(M.b, true, opts)
        vim.api.nvim_win_set_option(M.wid, "winhl", "Normal:TelescopePreviewNormal")
        vim.api.nvim_win_set_option(M.wid, "conceallevel", 3)
        vim.cmd('autocmd WinClosed <buffer> lua require("dict").winclosed()')
    end
    vim.api.nvim_win_set_cursor(M.wid, {1, 0})
end

return M
