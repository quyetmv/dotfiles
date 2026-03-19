-- Neovim configuration managed by chezmoi

vim.loader.enable() -- Speed up startup

require('hbb.lazy') -- Lazy load plugins
require('hbb.settings') -- Define global settings
require('hbb.keymaps') -- Define global keymaps
require('hbb.autocommands') -- Define global autocommands
