-- ============================================================================
-- gestor.lua — bootstrap de lazy.nvim (gestor de plugins)
-- ============================================================================
-- Se instala solo la primera vez. lazy-lock.json SE VERSIONA para que Linux y
-- Windows tengan los mismos plugins: actualizar con :Lazy sync y commitear el lock.
-- ============================================================================

-- Ruta de instalación de lazy.nvim (dentro del data-dir de nvim, no del repo).
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'

-- Clonar lazy.nvim si todavía no está (primer arranque en una máquina nueva).
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local repo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', repo, lazypath })
  if vim.v.shell_error ~= 0 then
    error('Error clonando lazy.nvim:\n' .. out)
  end
end

-- Anteponer lazy.nvim al runtimepath para poder requerirlo.
vim.opt.rtp:prepend(lazypath)

-- Arrancar lazy.nvim. { import = 'plugins' } le dice que cargue cada archivo de
-- lua/plugins/ como una spec (así sumar/quitar plugins = crear/borrar archivos).
require('lazy').setup({
  { import = 'plugins' },
}, {
  -- Qué colorscheme usa la VENTANA DE INSTALACIÓN de lazy en el primer arranque
  -- (cuando el tema real todavía no está clonado). No cambia el tema de la sesión.
  install = { colorscheme = { 'vscode' } },
  -- No chequea updates al arrancar (cero red al inicio). Las actualizaciones se
  -- hacen a mano con :Lazy sync y se commitea el lazy-lock.json resultante.
  checker = { enabled = false },
  -- Ningún plugin de esta config usa luarocks (lo confirma :checkhealth lazy con
  -- "no plugins require luarocks"). Sin esto, el health tira un ERROR y dos
  -- WARNING por hererocks/lua 5.1 ausentes → ruido que tapa los problemas reales.
  rocks = { enabled = false },
})
