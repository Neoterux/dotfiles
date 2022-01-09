
local let = vim.g
let.coq_settings = {
    auto_start = 'shut-up'
}
-- vim.cmd [[let g:coq_settings = {'auto_start': v:true}]]
require('nvim-treesitter.configs').setup{
    highlight = {
        enable = true
    }
}


