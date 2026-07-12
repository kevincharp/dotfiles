-- ============================================================================
-- opciones.lua — comportamiento base del editor (vim.opt)
-- ============================================================================
-- Ajustes que no dependen de ningún plugin. Pensados para que nvim se sienta
-- cómodo y parecido a VSCode desde el arranque. Cada bloque explica el porqué.
-- ============================================================================

local opt = vim.opt

-- --- Números de línea ---
opt.number = true          -- número de línea absoluto (como VSCode)
opt.relativenumber = true  -- + número relativo: facilita saltos con j/k (ej. 5j)

-- --- Ratón y portapapeles ---
opt.mouse = 'a'            -- ratón activo en todos los modos (click, scroll, seleccionar)
-- Usa el portapapeles del SISTEMA para yank/paste (Ctrl+C/V del SO). En Linux
-- Wayland lo resuelve wl-clipboard (ya instalado); en Windows, el nativo.
opt.clipboard = 'unnamedplus'

-- --- Indentación ---
opt.expandtab = true       -- Tab inserta espacios, no un carácter tab
opt.tabstop = 2            -- un tab se ve como 2 espacios
opt.shiftwidth = 2         -- la indentación automática usa 2 espacios
opt.smartindent = true     -- indentación inteligente al abrir bloques

-- --- Búsqueda ---
opt.ignorecase = true      -- búsqueda sin distinguir mayúsculas...
opt.smartcase = true       -- ...salvo que escribas alguna mayúscula (entonces sí distingue)
opt.hlsearch = true        -- resalta todas las coincidencias
opt.incsearch = true       -- salta a la coincidencia mientras tipeás

-- --- Apariencia ---
opt.termguicolors = true   -- colores de 24 bits (imprescindible para el tema VSCode)
opt.signcolumn = 'yes'     -- columna de signos siempre visible (git/errores) → no "salta" el texto
opt.cursorline = true      -- resalta la línea del cursor (como VSCode)
opt.scrolloff = 8          -- mantiene 8 líneas de contexto arriba/abajo del cursor
opt.wrap = false           -- no parte las líneas largas (scroll horizontal)
opt.showmode = false       -- no muestra "-- INSERT --" (la statusline lo hará)

-- --- Splits (ventanas divididas) ---
opt.splitright = true      -- split vertical abre a la DERECHA (natural, como VSCode)
opt.splitbelow = true      -- split horizontal abre ABAJO

-- --- Archivos y persistencia ---
opt.undofile = true        -- historial de undo persistente entre sesiones (deshacer tras cerrar)
opt.swapfile = false       -- sin archivos .swap (molestan más de lo que ayudan hoy)

-- --- Rendimiento / UX ---
opt.updatetime = 250       -- respuesta más ágil (diagnósticos, git signs)
opt.timeoutlen = 400       -- ventana para completar un atajo con líder (which-key lo aprovecha)

-- --- Caracteres invisibles (útil para ver espacios/tabs, como en VSCode) ---
opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
