-- vim: shiftwidth=2:foldmethod=marker
local fn = vim.fn

-- inspect
function inspect(item)
    vim.pretty_print(item)
end

local M = {}

function M.executable(name)
return (fn.executable(name) > 0)
end

function M.may_create_dir()
  local fpath = fn.expand('<afile>')
  local parent_dir = fn.fnamemodify(fpath, ":p:h")
  local res = fn.isdirectory(parent_dir)

  if res == 0 then
    fn.mkdir(parent_dir, 'p')
  end
end

return M
