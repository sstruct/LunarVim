local plugin_loader = {}

local in_headless = #vim.api.nvim_list_uis() == 0

local utils = require "lvim.utils"
local Log = require "lvim.core.log"
-- we need to reuse this outside of init()
local compile_path = get_config_dir() .. "/plugin/packer_compiled.lua"

function plugin_loader.init(opts)
  opts = opts or {}

  local install_path = opts.install_path or vim.fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"
  local package_root = opts.package_root or vim.fn.stdpath "data" .. "/site/pack"
  local updating = opts.updating or false

  if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
    vim.fn.system { "git", "clone", "--depth", "1", "https://github.com/wbthomason/packer.nvim", install_path }
    vim.cmd "packadd packer.nvim"
  end

  local log_level = in_headless and "debug" or "warn"
  if lvim.log and lvim.log.level then
    log_level = lvim.log.level
  end

  local _, packer = pcall(require, "packer")
  packer.init {
    package_root = package_root,
    compile_path = compile_path,
    auto_reload_compiled = not updating,
    auto_clean = true,
    log = {
      level = log_level,
      highlights = not updating,
      use_file = not updating,
    },
    git = {
      clone_timeout = 300,
      subcommands = {
        -- this is more efficient than what Packer is using
        fetch = "fetch --no-tags --no-recurse-submodules --update-shallow --progress",
      },
    },
    max_jobs = 50,
    display = not updating and {
      open_fn = function()
        return require("packer.util").float { border = "rounded" }
      end,
    } or nil,
  }

  vim.cmd [[autocmd User PackerComplete lua require('lvim.utils.hooks').run_on_packer_complete()]]
end

-- packer expects a space separated list
local function pcall_packer_command(cmd, kwargs)
  local status_ok, msg = pcall(function()
    require("packer")[cmd](unpack(kwargs or {}))
  end)
  if not status_ok then
    Log:warn(cmd .. " failed with: " .. vim.inspect(msg))
    Log:trace(vim.inspect(vim.fn.eval "v:errmsg"))
  end
end

function plugin_loader.cache_clear()
  if vim.fn.delete(compile_path) == 0 then
    Log:debug "deleted packer_compiled.lua"
  end
end

function plugin_loader.recompile()
  plugin_loader.cache_clear()
  pcall_packer_command "compile"
  if utils.is_file(compile_path) then
    Log:debug "generated packer_compiled.lua"
  end
end

function plugin_loader.load(configurations)
  Log:debug "loading plugins configuration"
  local packer_available, packer = pcall(require, "packer")
  if not packer_available then
    Log:warn "skipping loading plugins until Packer is installed"
    return
  end
  local status_ok, _ = xpcall(function()
    packer.reset()
    local use = packer.use
    for _, plugins in ipairs(configurations) do
      for _, plugin in ipairs(plugins) do
        use(plugin)
      end
    end
  end, debug.traceback)
  if not status_ok then
    Log:warn "problems detected while loading plugins' configurations"
    Log:trace(debug.traceback())
  end

  -- Colorscheme must get called after plugins are loaded or it will break new installs.
  -- Needs to be caught in case the colorscheme is invalid, but it shouldn't break things
  status_ok, _ = xpcall(function()
    vim.g.colors_name = lvim.colorscheme
    vim.cmd("colorscheme " .. lvim.colorscheme)
  end, debug.traceback)
  if not status_ok then
    Log:warn("unable to find colorscheme " .. lvim.colorscheme)
    Log:trace(debug.traceback())
  end
end

function plugin_loader.get_core_plugins()
  local list = {}
  local plugins = require "lvim.plugins"
  for _, item in pairs(plugins) do
    table.insert(list, item[1]:match "/(%S*)")
  end
  return list
end

-- @deprecated
function plugin_loader.sync_core_plugins()
  vim.api.nvim_err_writeln "LvimSyncCorePlugins has been deprecated. Exit lvim and use `lvim --update-core` instead"
end

return plugin_loader
