vim.api.nvim_create_user_command("Practice", function()
    require("practice").start()
end, {})