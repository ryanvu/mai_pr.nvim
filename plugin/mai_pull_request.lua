-- plugin/mai_pull_request.lua
if vim.fn.has('nvim-0.7') == 0 then
  vim.api.nvim_err_writeln("mai_pull_request requires at least nvim-0.7")
  return
end

-- Load the plugin
require('mai_pull_request')
