local logger = require('timber'):new({ mode = 'file' })
local options = require('chomp.opts')
local M = {}

local function get_fail_fn(handler_name, called)
  return function(msg)
    called['fail'] = true
    logger:error('Could not install "%s": %s', handler_name, msg)
  end
end

local function get_success_fn(handler_name, called)
  return function()
    called['success'] = true
    logger:info('Installed handler "%s"', handler_name)
  end
end

local function file_matches_any_pattern(filename, patterns)
  for _, pattern in pairs(patterns) do
    local regex_obj = vim.regex(vim.fn.glob2regpat(pattern))
    if regex_obj:match_str(filename) then
      logger:info('MATCHED pattern %s', pattern)
      return true
    end
  end
  return false
end

local function install_with(handler_name, handler, config)
  if handler == nil then
    logger:error('No handler installed for "%s"', handler_name)
    return
  end
  local called = { success = false, fail = false }
  handler(config, get_success_fn(handler_name, called), get_fail_fn(handler_name, called))
  if called['success'] and called['fail'] then
    logger:warn('Both success and fail were called in "%s" handler.', handler_name)
  elseif not called['success'] and not called['fail'] then
    logger:warn('Must call either success_fn or fail_fn in "%s" handler.', handler_name)
  end
end

local function get_base_cmd_handler(config)
  return function(ev)
    local cmd = {}
    if type(config.cmd) == 'string' then
      if config["cmd"] == "lsp" then
        vim.lsp.buf.format({ async = false })
        return
      end
      logger:error('No handler for special cmd "%s".', config.cmd)
      return
    end
    local usr_cmd = config.cmd
    if type(config.cmd) == 'function' then
      usr_cmd = config.cmd()
    end
    for i, part in ipairs(usr_cmd) do
      if part == "$file" then
        cmd[i] = vim.api.nvim_buf_get_name(ev.buf)
      else
        cmd[i] = part
      end
    end
    local cmd_text = table.concat(cmd, " ")
    logger:info('Running "%s".', cmd_text)
    vim.system(cmd, {}, function(obj)
      if obj.stdout ~= '' and obj.stdout ~= nil then
        logger:debug('Ran cmd %s: %s', cmd_text, obj.stdout)
      end
      if obj.stderr ~= '' and obj.stderr ~= nil then
        logger:debug('Ran cmd %s: %s', cmd_text, obj.stderr)
      end
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(ev.buf) then
          vim.api.nvim_buf_call(ev.buf, function()
            vim.cmd('checktime')
          end)
        end
      end)
    end)--:wait()
  end
end

local default_event_handlers = {
  format = function(ev, config)
    if config["cmd"] == "lsp" then
      vim.lsp.buf.format({ async = false })
      return
    end
    get_base_cmd_handler(config)(ev)
  end
}

local function create_autocmd(augroup, config, events, fn)
  vim.api.nvim_create_autocmd(events, {
    desc = "Format file using " .. config[1] .. ": " .. config["desc"],
    group = augroup,
    pattern = config["pattern"],
    callback = fn,
  })
end

function M.buf_match(filename, configs)
  local matching_configs = {}
  for _, config in pairs(configs) do
    local patterns = config.pattern
    if file_matches_any_pattern(filename, patterns) then
      table.insert(matching_configs, config)
    end
  end
  return matching_configs
end

function M.buf_install(config)
  local name = config.install_handler
  if name == nil then
    logger:warn('No install_handler defined for "%s".', config[1])
    return
  end
  local install_handlers = options.get('install_handlers')
  local handler = install_handlers[name]
  if handler == nil then
    logger:warn('No handler available with the name "%s".', name)
    return
  end
  install_with(name, handler, config)
end

function M.buf_events(ev, config)
  local events = {}
  for i, item in ipairs(config.events) do
    if type(item) == 'string' then
      if string.sub(item, 1, 1) == '$' then
        local ev_handler = default_event_handlers(string.sub(2, -1))
        if ev_handler == nil then
          logger:error('Config %s events[%s] not ordered properly.', config[1], i)
          return
        end
        local curried_ev_handler = function(ev)
          return ev_handler(ev, config)
        end
        create_autocmd(ev.group, config, events, curried_ev_handler)
      else
        table.insert(events, item)
      end
    elseif type(item) == 'function' and not next(events) == nil then
      create_autocmd(ev.group, config, events, item)
      events = {}
    else
      logger:error('Config %s events[%s] not ordered properly.', config[1], i)
      return
    end
  end
  if next(events) ~= nil then
    create_autocmd(ev.group, config, events, get_base_cmd_handler(config))
  end
end

return M
