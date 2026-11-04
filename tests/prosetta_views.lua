vim.opt.runtimepath:append(vim.fn.getcwd())
vim.cmd('runtime plugin/practice.lua')
vim.o.columns, vim.o.lines = 120, 48
vim.notify = function() end
local practice = require('practice')
local temporary = vim.fn.tempname()
local root = temporary .. '/problems'
local id = 'c-' .. string.rep('1', 32)
local function write(path, lines)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    assert(vim.fn.writefile(lines, path) == 0)
end
local function lines(buffer) return vim.api.nvim_buf_get_lines(buffer or 0, 0, -1, false) end
local function text(buffer) return table.concat(lines(buffer), '\n') end
local function keys(value)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), 'xt', false)
end
local base = root .. '/fundamentals/example'
write(root .. '/index.json', { vim.json.encode({ categories = { { id = 'fundamentals', order = 1,
    concepts = { { id = id, order = 1 } } } }, concepts_by_id = {
    [id] = { title = 'Example', path = 'fundamentals/example', description = 'Metadata is not authored notes.' },
} }) })
write(temporary .. '/templates/concept/typescript/template.ts', { 'STARTER_CODE' })
write(temporary .. '/templates/concept/go/template.go', { 'GO_STARTER' })
write(base .. '/PROBLEM.md', { '# Practice statement', 'Return the requested output.' })
write(base .. '/README.md', { '# Authored explanation', 'My reasoning and complexity.' })
write(base .. '/typescript/main.ts', { 'SOLVED_CODE', '// exact authored implementation' })
-- A stub process verifies CLI transport without grading code inside the plugin.
local runner = temporary .. '/prosetta'
write(runner, {
    '#!/bin/sh',
    'printf "call\\n" >> ' .. vim.fn.shellescape(temporary .. '/calls'),
    'printf "%s\\n" "$@" > ' .. vim.fn.shellescape(temporary .. '/args'),
    'source=$(cat)',
    'printf "%s\\n" "$source" > ' .. vim.fn.shellescape(temporary .. '/stdin'),
    'case "$source" in',
    '  *BUILD_ERROR*) printf \'%s\\n\' \'{"schema_version":1,"status":"error","error":"Compiler diagnostic","test_results":[]}\'; exit 1 ;;',
    '  *DRAFT_PASS*) printf \'%s\\n\' \'{"schema_version":1,"status":"passed","test_results":[{"id":"1","passed":true,"status":"passed"}]}\' ;;',
    '  *) printf \'%s\\n\' \'{"schema_version":1,"status":"failed","test_results":[{"id":"1","passed":false,"status":"wrong_answer","message":"Wrong output"}]}\'; exit 1 ;;',
    'esac',
})
vim.fn.setfperm(runner, 'rwx------')
local baseline_buffers, baseline_windows = #vim.api.nvim_list_bufs(), #vim.api.nvim_list_wins()
practice.setup({ prosetta_command = runner, prosetta_catalog = root, advance_ms = 1 })
local lesson = 'prosetta.' .. id .. '.typescript'
assert(practice.start(lesson))
local draft, window = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
assert(vim.bo[draft].modifiable and not vim.bo[draft].readonly and text() == 'STARTER_CODE', 'practice must open the starter, not the solution')
assert(practice.status().view == 'practice')
vim.api.nvim_buf_set_lines(draft, 0, -1, false, { 'DRAFT_PASS', '// learner edits' })
vim.api.nvim_win_set_cursor(window, { 2, 3 })
local tick = vim.api.nvim_buf_get_changedtick(draft)
keys('\\v')
assert(practice.status().view == 'solution', 'View solution shortcut missing')
assert(text():find('SOLVED_CODE', 1, true) and vim.bo.filetype == 'typescript', 'authored solution or language filetype missing')
assert(not vim.bo.modifiable and vim.bo.readonly, 'solution must be read only')
assert(not pcall(vim.api.nvim_buf_set_lines, 0, 0, -1, false, { 'overwrite' }), 'solution allowed editing')
assert(not practice.status().passed and not practice.status().completed[lesson], 'viewing a solution marked completion')
assert(vim.fn.filereadable(temporary .. '/calls') == 0, 'reference viewing executed the CLI')
keys('q')
assert(vim.api.nvim_get_current_buf() == draft and practice.status().view == 'practice')
assert(vim.deep_equal(vim.api.nvim_win_get_cursor(window), { 2, 3 }), 'view changed the practice cursor')
assert(vim.api.nvim_buf_get_changedtick(draft) == tick and text(draft):find('DRAFT_PASS', 1, true), 'view replaced the practice draft')
vim.cmd('PracticeProblem')
assert(text():find('Practice statement', 1, true) and vim.bo.filetype == 'markdown')
keys('\\e')
assert(practice.status().view == 'explanation' and text():find('Authored explanation', 1, true), 'README explanation was not separate from the problem')
keys('\\v')
assert(practice.status().view == 'solution')
keys('q')
-- Even an explicit Run from a reference view must execute the learner's buffer.
vim.cmd('PracticeSolution')
vim.cmd('PracticeRun')
assert(text(vim.fn.bufnr(draft)):find('DRAFT_PASS', 1, true))
assert(table.concat(vim.fn.readfile(temporary .. '/stdin'), '\n') == text(draft), 'Run executed the displayed solution instead of the draft')
assert(not table.concat(vim.fn.readfile(temporary .. '/args'), '\n'):find('--all', 1, true), 'Run selected hidden cases')
assert(practice.status().passed)
keys('q')
vim.wait(30, function() return false end)
assert(practice.status().attempt == 1 and text(draft):find('DRAFT_PASS', 1, true), 'successful programming run reset the learner draft')
vim.cmd('PracticeSubmit')
assert(table.concat(vim.fn.readfile(temporary .. '/args'), '\n'):find('--all', 1, true), 'Submit did not select all cases')
vim.cmd('PracticeRun')
assert(not table.concat(vim.fn.readfile(temporary .. '/args'), '\n'):find('--all', 1, true), 'Submit mode leaked into later Run')
vim.api.nvim_buf_set_lines(draft, 0, -1, false, { 'BUILD_ERROR' })
assert(not practice.run(), 'compiler failure was accepted')
assert(practice.status().lesson == lesson and text(draft) == 'BUILD_ERROR', 'compiler failure discarded the draft')
vim.cmd('PracticeSolution')
assert(practice.reset())
assert(practice.status().view == 'practice' and vim.api.nvim_get_current_buf() == draft and text() == 'STARTER_CODE', 'reset did not restore only the starter')
-- Missing content is a truthful placeholder, never the other language's solution.
assert(practice.start('prosetta.' .. id .. '.go'))
vim.cmd('PracticeSolution')
assert(text():find('not available', 1, true) and not text():find('SOLVED_CODE', 1, true))
keys('q')
vim.fn.delete(base .. '/README.md')
vim.fn.delete(base .. '/PROBLEM.md')
assert(practice.start('prosetta.' .. id .. '.go'))
vim.cmd('PracticeExplanation')
assert(text():find('not been written', 1, true) and not text():find('Metadata', 1, true))
vim.cmd('PracticeProblem')
assert(text():find('not been written', 1, true))
-- Closing either the reference or the practice frame must release owned views.
vim.api.nvim_win_close(vim.api.nvim_get_current_win(), true)
vim.wait(20, function() return false end)
assert(practice.status().view == 'practice')
vim.cmd('PracticeSolution')
assert(practice.stop())
assert(#vim.api.nvim_list_bufs() == baseline_buffers and #vim.api.nvim_list_wins() == baseline_windows, 'Prosetta reference views leaked buffers/windows')
assert(practice.start(lesson))
local parent = vim.api.nvim_get_current_win()
vim.cmd('PracticeSolution')
vim.api.nvim_win_close(parent, true)
vim.wait(30, function() return practice.status().lesson == nil end)
assert(practice.status().lesson == nil and #vim.api.nvim_list_bufs() == baseline_buffers, 'external practice closure leaked a reference')
local claimed = false
vim.keymap.set('n', '\\v', function() claimed = true end)
assert(practice.start(lesson))
keys('\\v')
assert(claimed and practice.status().view == 'practice', 'View solution replaced a user mapping')
assert(practice.solution(), 'command fallback for View solution failed')
practice.setup({ prosetta_command = runner, prosetta_catalog = root })
assert(practice.status().lesson == nil and #vim.api.nvim_list_bufs() == baseline_buffers, 'setup leaked a reference view')
vim.keymap.del('n', '\\v')
assert(not practice.solution() and not practice.explanation() and not practice.submit(), 'inactive commands created a session')
assert(vim.deep_equal(vim.fn.readfile(base .. '/typescript/main.ts'), { 'SOLVED_CODE', '// exact authored implementation' }), 'reference file was modified')
vim.fn.delete(temporary, 'rf')
print('PASS: practice-first Prosetta views, read-only authored code/notes, retained drafts, public/all CLI transport, errors, no auto-reset, and cleanup')
