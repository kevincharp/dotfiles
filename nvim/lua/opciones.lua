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
-- DOS columnas de signos, no una: git y diagnósticos comparten esta columna, y con
-- 'yes' (una sola) el signo de error TAPA al de git cuando caen en la misma línea.
-- VSCode muestra los dos. El ancho fijo evita además que el texto "salte".
opt.signcolumn = 'yes:2'
opt.cursorline = true      -- resalta la línea del cursor (como VSCode)
opt.scrolloff = 8          -- mantiene 8 líneas de contexto arriba/abajo del cursor
opt.wrap = false           -- no parte las líneas largas (scroll horizontal)
opt.showmode = false       -- no muestra "-- INSERT --" (la statusline lo hará)
-- Borde redondeado para TODAS las ventanas flotantes (hover, signature, menús).
-- Opción global nueva de 0.11+: reemplaza tener que configurar `border` plugin
-- por plugin, y de paso los deja consistentes entre sí.
opt.winborder = 'rounded'

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

-- --- Plegado de código (folding), como el de VSCode ---
-- nvim 0.12 ya deja `foldexpr` apuntando a vim.treesitter.foldexpr() por defecto,
-- PERO `foldmethod` sigue siendo 'manual', que lo anula: sin estas líneas no hay
-- plegado en absoluto a pesar de tener treesitter andando.
opt.foldmethod = 'expr'
opt.foldlevel = 99         -- arrancar TODO desplegado (con 0 abriría todo colapsado)
opt.foldtext = ''          -- la línea plegada conserva su resaltado en vez de "+--- N líneas"
opt.foldcolumn = 'auto:1'  -- columna de plegado solo cuando hay algo que plegar
-- Atajos nativos, no hace falta mapear nada: za (alternar), zR (abrir todo),
-- zM (cerrar todo), zc/zo (cerrar/abrir el pliegue del cursor).

-- --- Proveedores legacy de plugins remotos: apagados a propósito ---
-- Ningún plugin de esta config usa Python/Ruby/Perl/Node como host remoto (eso es
-- el mecanismo viejo de plugins de vim). Sin esto, :checkhealth escupe 4 WARNING
-- por intérpretes ausentes y ese ruido tapa los problemas de verdad.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0
