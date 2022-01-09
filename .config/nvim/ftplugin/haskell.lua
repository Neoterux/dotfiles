
-- Haskell plugin configurations
--

let = vim.g
vim.cmd [[colorscheme gruvbox]]
-- Highlight
let.haskell_classic_highlighting    = true
let.haskell_enable_quantification   = true      -- enable hi of `forall`
let.haskell_enable_recursivedo      = true      -- enable hi of `mdo` and `rec`
let.haskell_enable_arrowsyntax      = true      -- enable hi of `proc`
let.haskell_enable_pattern_synonyms = true      -- enable hi of `pattern`
let.haskell_enable_typeroles        = true      -- enable hi of type roles
let.haskell_enable_static_pointers  = true      -- enable hi of `static`
let.haskell_backpack                = true      -- enable hi of backpack keywords
