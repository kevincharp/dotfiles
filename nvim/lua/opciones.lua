-- ============================================================================
-- opciones.lua — comportamiento base del editor (vim.opt)
-- ============================================================================

local opt = vim.opt

opt.number = true
opt.relativenumber = true

opt.mouse = 'a'
-- Reporta el movimiento del ratón: lo necesitan la X de las pestañas y dropbar.
opt.mousemoveevent = true
opt.clipboard = 'unnamedplus' -- portapapeles del sistema (wl-clipboard en Wayland)

opt.expandtab = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true -- distingue mayúsculas solo si se escribe alguna
opt.hlsearch = true
opt.incsearch = true

opt.termguicolors = true
-- Dos columnas: con una, el signo de diagnóstico tapa al de git en la misma línea.
opt.signcolumn = 'yes:2'
opt.cursorline = true
opt.scrolloff = 8
opt.wrap = false
opt.showmode = false -- el modo lo muestra la statusline
opt.winborder = 'rounded' -- borde de todas las ventanas flotantes

opt.splitright = true
opt.splitbelow = true

opt.undofile = true -- deshacer persiste entre sesiones
opt.swapfile = false

opt.updatetime = 250
opt.timeoutlen = 400 -- mismo valor que el delay de which-key

opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- foldexpr ya apunta a treesitter por defecto, pero foldmethod viene en 'manual'.
opt.foldmethod = 'expr'
opt.foldlevel = 99 -- arranca todo desplegado
opt.foldtext = '' -- la línea plegada conserva su resaltado
opt.foldcolumn = 'auto:1'

-- Ningún plugin usa hosts remotos; apagarlos quita cuatro avisos de :checkhealth.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0
