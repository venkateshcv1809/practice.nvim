if vim.g.loaded_practice then return end
vim.g.loaded_practice = true
vim.api.nvim_create_user_command('Practice', function(args)
    if args.args == '' then require('practice').home() else require('practice').start(args.args) end
end, {
    nargs = '?',
    complete = function(prefix)
        local matches = {}
        local ok, entries = pcall(require('practice').lessons)
        if not ok then return matches end
        for _, lesson in ipairs(entries) do
            if lesson.id:sub(1, #prefix) == prefix then matches[#matches + 1] = lesson.id end
        end
        return matches
    end,
    desc = 'Open practice menu or start a tutorial by ID',
})
vim.api.nvim_create_user_command('PracticeNavigate', function()
    require('practice').navigate()
end, {
    desc = 'Start navigation with optional hints',
})
vim.api.nvim_create_user_command('PracticeTyping', function(args)
    require('practice').typing(args.fargs[1] and vim.fn.expand(args.fargs[1]) or nil)
end, { nargs = '?', complete = 'file', desc = 'Type a reference file in native splits' })
for command, method in pairs({ PracticeCheck = 'check', PracticeReset = 'reset',
    PracticeTypingDemo = 'typing_demo', PracticeFinish = 'finish', PracticeMenu = 'home', PracticeHint = 'hint', PracticeNext = 'next', PracticeContinue = 'start', PracticeCatalogRefresh = 'refresh', PracticeStop = 'stop', PracticeList = 'list',
    PracticeProsetta = 'prosetta_list', PracticeProblem = 'problem', PracticeNew = 'new' }) do
    vim.api.nvim_create_user_command(command, function() require('practice')[method]() end, {})
end
