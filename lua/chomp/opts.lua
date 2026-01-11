local anvil_opts = require('anvil.opts')
local tbl_utils = require('anvil.utils.table')
local fn_utils = require('anvil.utils.function')

local M = {}

local options = {
  debug = false,
  install_handlers = {
    mason = function(config, success_fn, fail_fn)
      local mason_api = require("mason.api.command")
      local pkg = config[1]
      local filename = vim.fn.expand("$MASON/packages/" .. pkg)
      if not vim.uv.fs_stat(filename) then
        mason_api.MasonInstall({ pkg })
      end
      if vim.uv.fs_stat(filename) then
        success_fn()
      else
        fail_fn()
      end
    end
  },
  configs = {}
}

local type_info = {
  debug = 'boolean?',
  -- install_handler[[config, success_callback, fail_callback], nil]
  install_handlers = 'table[string, function[[table, function, function], nil]]?',
  configs = {
    'table?',
    repeated = true,
    shape = {
      'string',
      install_handler = 'string?',
      desc = 'string!',
      pattern = 'table[string]!',
      cmd = 'string|function[[], string]!',
      events = 'table[string]!',
      fallback = 'string?',
    },
  },
}

M.validate = fn_utils.partial(anvil_opts.validate, type_info)

function M.set(opts)
  -- Keep opts from the right.
  tbl_utils.merge_right(options, opts)
end

function M.get(key)
  if key ~= nil then
    return tbl_utils.deep_copy(options)[key]
  end
  return tbl_utils.deep_copy(options)
end

return M
