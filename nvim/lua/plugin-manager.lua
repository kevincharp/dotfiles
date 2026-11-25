-- ============================================================================
-- gestor.lua — bootstrap de lazy.nvim (gestor de plugins)
-- ============================================================================
-- Se instala solo en el primer arranque. lazy-lock.json se versiona: actualizar con
-- :Lazy sync y commitear el lock.
-- ============================================================================

local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local repo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', repo, lazypath })
  if vim.v.shell_error ~= 0 then
    error('Error clonando lazy.nvim:\n' .. out)
  end
end

vim.opt.rtp:prepend(lazypath)

-- Cada archivo de lua/plugins/ es una spec.
require('lazy').setup({
  { import = 'plugins' },
}, {
  -- Tema de la ventana de instalación del primer arranque.
  install = { colorscheme = { 'vscode' } },
  -- Sin red al arrancar.
  checker = { enabled = false },
  -- Ningún plugin usa luarocks; sin esto, :checkhealth lazy da errores por hererocks.
  rocks = { enabled = false },
})
