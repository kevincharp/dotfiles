-- ============================================================================
-- gestor.lua — bootstrap de lazy.nvim (gestor de plugins)
-- ============================================================================
-- lazy.nvim se instala solo la primera vez (clona el repo si no existe) y luego
-- carga TODOS los archivos de lua/plugins/. Cada uno devuelve una spec de plugin.
--
-- Reproducibilidad: lazy.nvim escribe lazy-lock.json con la versión exacta de
-- cada plugin. Ese lock SE VERSIONA en el repo → ambas máquinas (Linux/Windows)
-- instalan idénticos plugins. Para actualizar: :Lazy sync y commitear el lock.
--
-- El código de los plugins se instala en un directorio de DATOS del usuario
-- (~/.local/share/nvim en Linux), FUERA del repo, así que no ensucia el árbol.
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
  -- El instalador no elige tema al vuelo: dejamos el nuestro fijo abajo.
  install = { colorscheme = { 'vscode' } },
  -- Avisar cuando haya updates de plugins (no auto-actualiza: eso es manual + commit).
  checker = { enabled = false },
  -- Íconos: si hay Nerd Font, lazy usa glifos; si no, texto plano.
  ui = { icons = vim.g.have_nerd_font and {} or {} },
})
