-- vim: tw=2 ts=2 sw=2 expandtab smarttab
return {
  'akinsho/bufferline.nvim',
  version = '*',
  dependencies = 'nvim-tree/nvim-web-devicons',
  config = function()
    require('config.bufferline').setup()
  end,
}
