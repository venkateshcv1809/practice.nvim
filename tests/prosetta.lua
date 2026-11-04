vim.opt.runtimepath:append(vim.fn.getcwd())
vim.cmd('runtime plugin/practice.lua')
vim.o.columns = 120
vim.o.lines = 48

local command = assert(vim.env.PROSETTA_BIN, 'PROSETTA_BIN must name the Prosetta binary')
local project = assert(vim.env.PROSETTA_ROOT, 'PROSETTA_ROOT must name the Prosetta repository')
assert(vim.fn.executable(command) == 1, 'PROSETTA_BIN must be executable')

local practice = require('practice')
local catalog = project .. '/problems'
local id = 'c-2b23ca0786e0eb237f64cf2b8759bcc3'
practice.setup({
    prosetta_command = command,
    prosetta_catalog = catalog,
    prosetta_index = project .. '/dist/problems/index.json',
    prosetta_cwd = project,
})

local lessons = {}
for _, lesson in ipairs(practice.lessons()) do
    if lesson.tool == 'prosetta' then lessons[#lessons + 1] = lesson end
end
assert(#lessons == 5, 'catalog did not create one lesson per supported language')

vim.cmd('PracticeProsetta')
assert(vim.bo.filetype == 'practice_menu', 'Prosetta menu did not open')
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'xt', false)
assert(practice.status().tool == 'prosetta', 'Prosetta menu did not open a lesson')
vim.cmd('PracticeProblem')
local statement = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
assert(statement:find('Hello World', 1, true), 'problem view did not show the catalog statement')
vim.api.nvim_win_close(vim.api.nvim_get_current_win(), true)
practice.stop()

local extensions = { go = 'go', python = 'py', rust = 'rs', typescript = 'ts', zig = 'zig' }
for language, extension in pairs(extensions) do
    local lesson_id = 'prosetta.' .. id .. '.' .. language
    assert(practice.start(lesson_id), 'failed to start ' .. language .. ' lesson')
    assert(vim.bo.filetype == language, 'starter filetype mismatch for ' .. language)
    assert(not practice.check(), 'incomplete ' .. language .. ' starter unexpectedly passed')
    local draft = vim.api.nvim_get_current_buf()
    local starter = vim.api.nvim_buf_get_lines(draft, 0, -1, false)
    local source = vim.fn.readfile(catalog .. '/fundamentals/hello-world/' .. language .. '/main.' .. extension)
    vim.cmd('PracticeSolution')
    assert(vim.bo.readonly and not vim.bo.modifiable and vim.bo.filetype == language, 'reference was editable or had the wrong filetype')
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), source), 'reference source did not match ' .. language)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('q', true, false, true), 'xt', false)
    assert(vim.api.nvim_get_current_buf() == draft and vim.deep_equal(vim.api.nvim_buf_get_lines(draft, 0, -1, false), starter), 'reference view replaced starter')
    vim.api.nvim_buf_set_lines(draft, 0, -1, false, source)
    assert(practice.check(), 'valid ' .. language .. ' solution failed')
    assert(practice.submit(), 'all-case submission failed for ' .. language)
    assert(practice.status().completed[lesson_id], language .. ' completion was not recorded')
    assert(practice.stop(), 'failed to stop ' .. language .. ' lesson')
end

local bad_index = vim.fn.tempname()
vim.fn.writefile({ vim.json.encode({
    categories = { { concepts = { { id = id, order = 1 } } } },
    concepts_by_id = { [id] = { path = '../outside', title = 'Unsafe' } },
}) }, bad_index)
practice.setup({ prosetta_command = command, prosetta_catalog = catalog, prosetta_index = bad_index })
assert(not pcall(practice.lessons), 'unsafe catalog path was accepted when listing')
vim.fn.delete(bad_index)

print('PASS: Prosetta catalog lessons, read-only references, public/all runs, and all five native languages')
