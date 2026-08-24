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

-- --- Mover y duplicar líneas: Alt+↑/↓ y Alt+Shift+↓/↑, igual que VSCode ---
-- ANTES esto era J/K en modo visual, y estaba MAL: pisaba el J nativo (unir
-- líneas), que es un comando de uso diario. Alt+flechas no pisa nada.
--
-- Verificado que las teclas llegan a nvim en las tres capas de arriba:
--   Ptyxis/VTE      → Alt se codifica como prefijo ESC, Alt+flecha = CSI 1;3A/B.
--                     Ptyxis usa Alt+1..9 para pestañas, pero NO las flechas.
--   GNOME           → sus 5 atajos custom son Ctrl+Alt+T, Ctrl+Space,
--                     Ctrl+Shift+Esc, Super+Shift+S y Super+. — ninguno choca.
--   Windows Terminal → se queda alt+minus/period/w y alt+shift+d/±, no las
--                     flechas (Ctrl+flechas SÍ las toma para mover paneles, por
--                     eso acá se usa Alt y no Ctrl).
map('n', '<M-Down>', '<cmd>move .+1<CR>==', { desc = 'Mover línea abajo' })
map('n', '<M-Up>', '<cmd>move .-2<CR>==', { desc = 'Mover línea arriba' })
map('i', '<M-Down>', '<Esc><cmd>move .+1<CR>==gi', { desc = 'Mover línea abajo' })
map('i', '<M-Up>', '<Esc><cmd>move .-2<CR>==gi', { desc = 'Mover línea arriba' })
map('v', '<M-Down>', ":move '>+1<CR>gv=gv", { desc = 'Mover selección abajo' })
map('v', '<M-Up>', ":move '<-2<CR>gv=gv", { desc = 'Mover selección arriba' })

-- Duplicar la línea / la selección (el Alt+Shift+↓ de VSCode).
map('n', '<M-S-Down>', '<cmd>copy .<CR>', { desc = 'Duplicar línea abajo' })
map('n', '<M-S-Up>', '<cmd>copy .-1<CR>', { desc = 'Duplicar línea arriba' })
map('v', '<M-S-Down>', ":copy '><CR>gv", { desc = 'Duplicar selección abajo' })

-- --- Guardar con Ctrl+S (el reflejo universal) ---
-- Solo en normal y visual: en modo INSERT, <C-s> ya es un default de nvim 0.11+
-- (vim.lsp.buf.signature_help, ver los parámetros de la función que escribís) y
-- pisarlo sería cambiar peor por mejor.
-- Nota: <C-s> normalmente muere en el flow control del tty (IXON), pero DENTRO de
-- nvim no: nvim apaga IXON e ISIG al tomar la terminal. En la shell sí aplica.
map({ 'n', 'v' }, '<C-s>', '<cmd>write<CR>', { desc = 'Guardar archivo' })

-- --- Borrar sin ensuciar el portapapeles ---
-- Con clipboard = 'unnamedplus' (ver opciones.lua), d/x/c escriben al portapapeles
-- del SO: borrar una línea te destruye lo que habías copiado de Chrome. Estos van
-- al registro "negro" (_), que descarta el texto en vez de guardarlo.
map({ 'n', 'v' }, '<leader>d', '"_d', { desc = 'Borrar sin tocar el portapapeles' })
map({ 'n', 'v' }, '<leader>x', '"_x', { desc = 'Borrar carácter sin tocar el portapapeles' })

-- --- Mantener el cursor centrado al saltar media página (Ctrl+d / Ctrl+u) ---
map('n', '<C-d>', '<C-d>zz', { desc = 'Media página abajo (centrado)' })
map('n', '<C-u>', '<C-u>zz', { desc = 'Media página arriba (centrado)' })

-- Resaltar brevemente el texto copiado (yank). Ayuda a ver qué se copió.
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Resaltar el texto copiado',
  group = vim.api.nvim_create_augroup('resaltar-yank', { clear = true }),
  callback = function()
    -- vim.highlight quedó DEPRECADO en 0.11 (renombrado a vim.hl) y se elimina en
    -- nvim 2.0. El aviso de deprecación es silencioso, así que no se nota: se
    -- verificó interceptando vim.deprecate.
    vim.hl.on_yank()
  end,
})
