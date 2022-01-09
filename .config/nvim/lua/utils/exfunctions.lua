-- Extra functions for variety of thing in this configuration
local api = vim.api
local fn = vim.fn
local M = {}

function M.openTerminal()
    print('Hola :)')
    api.nvim_command('normal \\<C-l>')
    api.nvim_command('normal \\<C-l>')
    api.nvim_command('normal \\<C-l>')
    api.nvim_command('normal \\<C-l>')
    local bufNum = fn.bufnr('%')
    local bufType = fn.getbufvar(bufNum, '&buftype', 'not found')
    if bufType == 'terminal' then
        api.nvim_command('q')
    else
        api.nvim_command('vsp term://$SHELL')
        api.nvim_command('set nonu')
        api.nvim_command('set nornu')
        vim.cmd [[silent au BufLeave <buffer> stopinsert!]]
        vim.cmd [[silent au BufWinEnter,WinEnter <buffer> startinsert!]]
        api.nvim_command('tnoremap <buffer> <C-h> <C-\\><C-n><C-w><C-h>')
        api.nvim_command('tnoremap <buffer> <C-t> <C-\\><C-n>:q<CR>')
        api.nvim_command('tnoremap <buffer> <C-\\><C-\\> <C-\\><C-n>')
    end
end


return M
