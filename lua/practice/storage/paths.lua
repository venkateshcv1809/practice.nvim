local M = {}
-- Resolving paths has no filesystem side effects. Writers create their own directories.
function M.resolve(overrides)
    local paths = {}
    for key in pairs(overrides or {}) do
        assert(key == 'state' or key == 'cache' or key == 'data', 'unknown storage path: ' .. tostring(key))
    end
    for _, key in ipairs({ 'state', 'cache', 'data' }) do
        local path = (overrides or {})[key] or (vim.fn.stdpath(key) .. '/nvim-practice')
        assert(type(path) == 'string' and (path:sub(1, 1) == '/' or path:match('^%a:[/\\]')),
            'storage.' .. key .. ' must be an absolute path')
        paths[key] = vim.fn.fnamemodify(path, ':p'):gsub('[/\\]+$', '')
    end
    return paths
end
return M
