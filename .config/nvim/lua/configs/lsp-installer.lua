-- vim: sw=2: foldmethod=marker
require("nvim-lsp-installer").setup{
  ui = {
    icons = {
      server_installed = "✓",
      server_pending = "➜",
      server_uninstalled = "✗"
    }
  }
}
