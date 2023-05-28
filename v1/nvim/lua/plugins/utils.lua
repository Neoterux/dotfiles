-- vim: tw=2 ts=2 sw=2 expandtab smarttab
return {
  {
    'j-hui/fidget.nvim',
    config = function()
      require('fidget').setup{}
    end
  },
  {
    'junegunn/fzf.vim',
    dependencies = {
      {
        'junegunn/fzf',
        build = function()
          vim.cmd [[fzf#install()]]
        end,
      },
    },
    lazy = false
  },
}
