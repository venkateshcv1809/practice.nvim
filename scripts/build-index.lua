-- Maintainer command: nvim --headless -u NONE -l scripts/build-index.lua [pack-root]
vim.opt.runtimepath:append(vim.fn.getcwd())
local root = arg[1] or 'content/builtin'
local index = require('practice.catalog.providers.files').build(root, root .. '/index.json')
print(('Indexed %d tutorials in %s'):format(#index.tutorials, root))
