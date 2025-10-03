local function dwarn(msg) vim.notify(msg, vim.log.levels.WARN, { title = "dict" }) end
local from_picker = false
local telewarn = true
local wlist = {}
local wid

local M = {}

local function start()
    -- Each combination of dictionaries requires its own cache file
    local cache_file = ""
    local diclist = {}
    if M.opts.dict then
        cache_file = M.opts.cache_dir .. "/index_" .. M.opts.dict
        diclist = { M.opts.dict }
    else
        cache_file = M.opts.cache_dir .. "/index"
        local dl = vim.split(vim.fn.glob(M.opts.dict_dir .. "/" .. "*.index"), "\n")
        local d = ""
        for _, v in pairs(dl) do
            d = string.gsub(v, ".*/", "")
            d = string.gsub(d, ".index", "")
            table.insert(diclist, d)
            cache_file = cache_file .. "_" .. d
        end
    end

    if vim.fn.isdirectory(M.opts.cache_dir) == 0 then
        vim.fn.mkdir(M.opts.cache_dir, "p")
    end

    -- Use the cache file if it already exists
    local f = io.open(cache_file, "r")
    if f then
        for line in f:lines() do
            table.insert(wlist, line)
        end
        f:close()
        return true
    end

    -- Create the cache file
    local tmplist = {}
    for _, v in pairs(diclist) do
        f = io.open(M.opts.dict_dir .. "/" .. v .. ".index", "r")
        if f == nil then
            dwarn("Could not open '" .. M.opts.dict_dir .. "/" .. v .. "'")
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
            if tmplist[i] ~= tmplist[i + 1] then table.insert(wlist, tmplist[i]) end
        else
            table.insert(wlist, tmplist[i])
        end
    end

    if #wlist == 0 then
        dwarn("Could not fill the list of words")
        return false
    end

    -- Save the cache file
    f = io.open(cache_file, "w")
    if not f then
        dwarn("Could not open '" .. cache_file .. "' for writing")
        return false
    end
    for _, v in pairs(wlist) do
        f:write(v .. "\n")
    end
    f:close()
    return true
end

local function pick_word(wrd)
    if not wlist then M.setup() end
    if #wlist == 0 then
        if not start() then return end
    end

    local has_telescope = pcall(require, "telescope")
    if not has_telescope then
        if telewarn then
            vim.notify(
                string.format(
                    '"%s" not found. Telescope is required to show a list of similar words.',
                    wrd
                ),
                vim.log.levels.WARN,
                { title = "dict.nvim" }
            )
            telewarn = false
        end
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers
        .new({ default_text = wrd }, {
            finder = finders.new_table({
                results = wlist,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry,
                        ordinal = entry,
                    }
                end,
            }),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, _)
                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    if selection and selection.value then
                        from_picker = true
                        M.lookup(selection.value)
                    end
                end)
                return true
            end,
        })
        :find()
end

local function winclosed() wid = nil end

local get_cword = function()
    local line = vim.fn.getline(".")
    local cpos = vim.fn.getpos(".")
    if type(line) == "string" then
        local cchar = string.sub(line, cpos[3], cpos[3])
        if cchar == "" or string.match(cchar, "%s") or string.match(cchar, "%p") then
            return nil
        end
        return vim.fn.expand("<cword>")
    end
    return nil
end

local function replace()
    local wrd = get_cword()
    if wrd then
        vim.api.nvim_win_close(0, false)
        vim.cmd("normal! ciw" .. wrd)
        vim.cmd("stopinsert")
    end
end

M.opts = {
    dict = nil,
    cache_dir = vim.env.HOME .. "/.cache/dict.nvim",
    dict_dir = "/usr/share/dictd",
}

function M.setup(config)
    if config then
        for k, v in pairs(config) do
            M.opts[k] = v
        end
    end
end

function M.lookup(wrd)
    if not wlist then M.setup() end
    if #wlist == 0 then
        if not start() then return end
    end

    if not wrd then
        wrd = get_cword()
        if not wrd then return end
    end

    local a
    if M.opts.dict then
        a, _ = io.popen("dict -d " .. M.opts.dict .. " '" .. wrd .. "' 2>/dev/null", "r")
    else
        a, _ = io.popen("dict '" .. wrd .. "' 2>/dev/null", "r")
    end
    if not a then
        dwarn("Error running: " .. "dict '" .. wrd .. "'")
        return
    end
    local output = a:read("*a")
    local suc, ecd, cd
    suc, ecd, cd = a:close()
    if not suc then
        dwarn(
            "Error running dict: "
                .. tostring(suc)
                .. " "
                .. tostring(ecd)
                .. " "
                .. tostring(cd)
        )
        return
    end

    if output == "" then
        if from_picker then
            from_picker = false
            vim.api.nvim_echo(
                { { "dictd: no definitions found for " }, { wrd, "Identifier" } },
                false,
                {}
            )
        else
            pick_word(wrd)
        end
        return
    end
    from_picker = false

    -- Pad space on the left
    output = string.gsub(output, "\n", "\n ")
    -- Minor improvement to WordNet
    output = string.gsub(output, "\n       ([a-z]+) 1: ", "\n     %1\n       1: ")
    -- Mark end of definition with non-separable space
    output = string.gsub(output, "\n \n From ", "\n \n From ")
    -- Mark beginning of pronunciation in Gcide
    output = string.gsub(output, "\\ %(", "\\ (")

    local outlines = vim.split("\n" .. output, "\n")

    if not M.b then
        M.b = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = M.b })
        vim.api.nvim_set_option_value("bufhidden", "hide", { scope = "local", buf = M.b })
        vim.api.nvim_set_option_value("swapfile", false, { scope = "local", buf = M.b })
        vim.api.nvim_set_option_value("tabstop", 2, { scope = "local", buf = M.b })
        vim.api.nvim_set_option_value("undolevels", -1, { scope = "local", buf = M.b })
        vim.api.nvim_set_option_value("syntax", "dict", { scope = "local", buf = M.b })
        vim.keymap.set("n", "q", ":quit<CR>", { silent = true, buffer = M.b })
        vim.keymap.set("n", "<Esc>", ":quit<CR>", { silent = true, buffer = M.b })
        vim.keymap.set("n", "<Enter>", replace, { silent = false, buffer = M.b })
    end
    vim.api.nvim_buf_set_lines(M.b, 0, -1, true, outlines)

    if not wid then
        -- Center the window
        local nc = vim.o.columns
        local fcol = 2
        if nc > 82 then fcol = math.floor((nc - 80) / 2) end
        local wh = vim.api.nvim_win_get_height(0) - 2
        local fheight
        if wh > #outlines then
            fheight = #outlines
        else
            fheight = wh
        end
        local frow = math.floor((wh - fheight) / 2)

        local o = {
            relative = "win",
            width = 80,
            height = fheight,
            col = fcol,
            row = frow,
            anchor = "NW",
            style = "minimal",
            noautocmd = true,
        }
        wid = vim.api.nvim_open_win(M.b, true, o)
        vim.api.nvim_set_option_value(
            "winhl",
            "Normal:TelescopePreviewNormal",
            { win = wid }
        )
        vim.api.nvim_set_option_value("conceallevel", 3, { win = wid })
        vim.api.nvim_create_autocmd("WinClosed", { buffer = 0, callback = winclosed })
    end
    vim.api.nvim_win_set_cursor(wid, { 1, 0 })
end

return M
