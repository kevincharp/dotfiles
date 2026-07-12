-- ============================================================================
-- atajos.lua — mapeos de teclado NATIVOS
-- ============================================================================
-- Por ahora solo atajos idiomáticos de nvim (líder = espacio). La mímica de
-- teclado de VSCode (Ctrl+P, Ctrl+Shift+P, Ctrl+`, Ctrl+B) se sumará más
-- adelante, cuando ya haya soltura con lo nativo — irá en su propio archivo
-- sin tocar esto.
--
-- Cada plugin además define sus propios atajos en su archivo (lua/plugins/*).
-- Acá viven solo los que no dependen de ningún plugin.
-- ============================================================================

local map = vim.keymap.set

-- Quitar el resaltado de búsqueda al apretar <Esc> (queda molesto tras buscar).
map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Quitar resaltado de búsqueda' })

-- --- Moverse entre ventanas (splits) con Ctrl + h/j/k/l, sin el prefijo Ctrl-w ---
map('n', '<C-h>', '<C-w><C-h>', { desc = 'Ir a la ventana izquierda' })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'Ir a la ventana derecha' })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'Ir a la ventana de abajo' })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'Ir a la ventana de arriba' })

-- --- Guardar y salir con el líder (cómodo mientras se aprenden los comandos) ---
map('n', '<leader>w', '<cmd>write<CR>', { desc = 'Guardar archivo' })
map('n', '<leader>q', '<cmd>quit<CR>', { desc = 'Cerrar ventana' })

-- --- Mover líneas seleccionadas arriba/abajo en modo visual (como Alt+↑/↓ de VSCode) ---
map('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Mover selección abajo' })
map('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Mover selección arriba' })

-- --- Mantener el cursor centrado al saltar media página (Ctrl+d / Ctrl+u) ---
map('n', '<C-d>', '<C-d>zz', { desc = 'Media página abajo (centrado)' })
map('n', '<C-u>', '<C-u>zz', { desc = 'Media página arriba (centrado)' })

-- Resaltar brevemente el texto copiado (yank). Ayuda a ver qué se copió.
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Resaltar el texto copiado',
  group = vim.api.nvim_create_augroup('resaltar-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
