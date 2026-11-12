-- ============================================================================
-- atajos.lua — mapeos de teclado nativos (líder = espacio)
-- ============================================================================
-- Atajos que no dependen de ningún plugin; cada plugin define los suyos.
-- ============================================================================

local map = vim.keymap.set

map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Quitar resaltado de búsqueda' })

map('n', '<C-h>', '<C-w><C-h>', { desc = 'Ir a la ventana izquierda' })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'Ir a la ventana derecha' })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'Ir a la ventana de abajo' })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'Ir a la ventana de arriba' })

map('n', '<leader>w', '<cmd>write<CR>', { desc = 'Guardar archivo' })
map('n', '<leader>q', '<cmd>quit<CR>', { desc = 'Cerrar ventana' })

-- Alt+flechas como en VSCode: no pisan nativos y llegan a nvim en Ptyxis y Windows
-- Terminal (Ctrl+flechas no).
map('n', '<M-Down>', '<cmd>move .+1<CR>==', { desc = 'Mover línea abajo' })
map('n', '<M-Up>', '<cmd>move .-2<CR>==', { desc = 'Mover línea arriba' })
map('i', '<M-Down>', '<Esc><cmd>move .+1<CR>==gi', { desc = 'Mover línea abajo' })
map('i', '<M-Up>', '<Esc><cmd>move .-2<CR>==gi', { desc = 'Mover línea arriba' })
map('v', '<M-Down>', ":move '>+1<CR>gv=gv", { desc = 'Mover selección abajo' })
map('v', '<M-Up>', ":move '<-2<CR>gv=gv", { desc = 'Mover selección arriba' })

map('n', '<M-S-Down>', '<cmd>copy .<CR>', { desc = 'Duplicar línea abajo' })
map('n', '<M-S-Up>', '<cmd>copy .-1<CR>', { desc = 'Duplicar línea arriba' })
map('v', '<M-S-Down>', ":copy '><CR>gv", { desc = 'Duplicar selección abajo' })

-- Solo en normal y visual: en insert, <C-s> es el signature_help nativo.
map({ 'n', 'v' }, '<C-s>', '<cmd>write<CR>', { desc = 'Guardar archivo' })

-- Con clipboard = 'unnamedplus', d/x pisan el portapapeles del sistema; estos van al
-- registro que descarta el texto.
map({ 'n', 'v' }, '<leader>d', '"_d', { desc = 'Borrar sin tocar el portapapeles' })
map({ 'n', 'v' }, '<leader>x', '"_x', { desc = 'Borrar carácter sin tocar el portapapeles' })

map('n', '<C-d>', '<C-d>zz', { desc = 'Media página abajo (centrado)' })
map('n', '<C-u>', '<C-u>zz', { desc = 'Media página arriba (centrado)' })

vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Resaltar el texto copiado',
  group = vim.api.nvim_create_augroup('resaltar-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})
