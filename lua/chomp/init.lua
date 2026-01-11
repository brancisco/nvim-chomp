local logger = require("timber").setup({
  on = true,
  logfile = '/tmp/nvim.brandon/chomp.log',
  cleanup = false,
}):new({
  mode = 'file',
})
logger:debug("Logger initialized.")
local chomp = require("chomp.core")
local options = require("chomp.opts")

local M = {}


M.autocmd_group = vim.api.nvim_create_augroup("chomp", { clear = true })

local function install_autocmd(config)
  vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile" }, {
    once = true,
    desc = ('Installs autocmd for "%s": %s.'):format(config[1], config.desc),
    group = M.autocmd_group,
    pattern = config.pattern,
    callback = function(ev)
      logger:info('Autocmd installing "%s": "%s" for file "%s".', config[1], config.desc, ev.file)
      chomp.buf_install(config)
      chomp.buf_events(ev, config)
    end,
  })
end

function M.setup(opts)
  logger:debug("Setup called.")
  local _, errors = options.validate(opts)
  if errors ~= nil then
    for _, e in ipairs(errors) do
      logger:error(e)
    end
    return
  end
  options.set(opts)
  local configs = options.get('configs')
  for _, config in ipairs(configs) do
    if config.install_handler then
      install_autocmd(config)
    end
  end
end

return M
