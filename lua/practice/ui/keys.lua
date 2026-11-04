-- Buffer-local plugin mappings; native editing keys retain their Neovim meaning.
local M = {}
local installed = {}
local group = vim.api.nvim_create_augroup('PracticeKeymaps', { clear = true })
vim.api.nvim_create_autocmd('BufWipeout', { group = group, callback = function(args)
    local buffer, entry = args.buf, installed[args.buf]
    if entry then
        -- BufWipeout also fires before renaming a live buffer, e.g. its first :write.
        vim.schedule(function()
            if installed[buffer] == entry and not vim.api.nvim_buf_is_valid(buffer) then installed[buffer] = nil end
        end)
    end
end })
local definitions = {
    menu = { key = 'm', command = 'PracticeMenu', label = 'Menu' },
    check = { key = 'c', command = 'PracticeCheck', label = 'Check' },
    reset = { key = 'r', command = 'PracticeReset', label = 'Retry' },
    next = { key = 'n', command = 'PracticeNext', label = 'Next' },
    new = { key = 'g', command = 'PracticeNew', label = 'New board' },
    hint = { key = 'h', command = 'PracticeHint', label = 'Hint' },
    problem = { key = 'p', command = 'PracticeProblem', label = 'Problem' },
    solution = { key = 'v', command = 'PracticeSolution', label = 'View solution' },
    explanation = { key = 'e', command = 'PracticeExplanation', label = 'Explanation' },
    submit = { key = 's', command = 'PracticeSubmit', label = 'Submit all' },
    finish = { key = 'f', command = 'PracticeFinish', label = 'Finish' },
}
local function prefix()
    local value = vim.g.maplocalleader
    return value == nil and '\\' or value
end
local function display(value)
    return value:gsub(' ', '<Space>'):gsub('\t', '<Tab>')
end
function M.clear(buffer)
    local entry = installed[buffer]
    installed[buffer] = nil
    if not entry then return end
    if not vim.api.nvim_buf_is_valid(buffer) then return end
    vim.api.nvim_buf_call(buffer, function()
        for _, mapping in ipairs(entry.maps) do
            local current = vim.fn.maparg(mapping.lhs, 'n', false, true)
            if current.buffer and current.buffer ~= 0 and ((mapping.callback and current.callback == mapping.callback)
                or (mapping.rhs and current.rhs == mapping.rhs)) then
                vim.keymap.del('n', mapping.lhs, { buffer = buffer })
            end
        end
    end)
end
function M.install(buffer, names, actions)
    M.clear(buffer)
    local bindings, entry = {}, { maps = {} }
    installed[buffer] = entry
    vim.api.nvim_buf_call(buffer, function()
        for _, name in ipairs(names) do
            local definition = assert(definitions[name], 'unknown practice action: ' .. name)
            local plug = '<Plug>(' .. definition.command .. ')'
            local callback = actions[name]
            if callback then
                vim.keymap.set('n', plug, callback, { buffer = buffer, silent = true, desc = 'Practice: ' .. definition.label })
                entry.maps[#entry.maps + 1] = { lhs = plug, callback = callback }
                local lhs = prefix() .. definition.key
                if vim.fn.hasmapto(plug, 'n') == 0 and vim.fn.mapcheck(lhs, 'n') == '' then
                    vim.keymap.set('n', lhs, plug, { buffer = buffer, remap = true, silent = true,
                        desc = 'Practice: ' .. definition.label })
                    entry.maps[#entry.maps + 1] = { lhs = lhs, rhs = plug }
                    bindings[name] = display(lhs)
                else
                    bindings[name] = ':' .. definition.command
                end
            end
        end
    end)
    return bindings
end
function M.controls(names, bindings, labels)
    local items = {}
    for _, name in ipairs(names) do
        local definition = definitions[name]
        local binding = (bindings and bindings[name])
            or (bindings == nil and (display(prefix()) .. definition.key)) or (':' .. definition.command)
        local label = (labels or {})[name] or definition.label
        items[#items + 1] = binding:sub(1, 1) == ':' and binding or (binding .. ' ' .. label)
    end
    return items
end
return M
