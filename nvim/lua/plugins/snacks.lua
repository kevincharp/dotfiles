-- ============================================================================
-- snacks.lua — módulos de folke (explorador, pickers, ayudas visuales)
-- ============================================================================
-- Activos: explorer, picker, input, indent, words, statuscolumn y scroll.
-- Apagados: image (Ptyxis no soporta el protocolo kitty), dashboard, notifier,
-- zen, dim. <leader>e abre/cierra el árbol; dentro: a crear, d borrar,
-- r renombrar, m mover, c/p copiar/pegar, H/I ocultos/ignorados, ? ayuda.
-- ============================================================================

return {
  'folke/snacks.nvim',
  priority = 1000, -- carga temprano (varios módulos deben estar listos al inicio)
  lazy = false,
  opts = {
    -- Árbol de archivos lateral. La posición y el ancho imitan al Explorer de VSCode.
    explorer = {
      enabled = true,
    },
    -- Motor de selección flotante (lo usan el filtro del árbol y los pickers).
    picker = {
      enabled = true,
      sources = {
        explorer = {
          -- OJO con el nivel de anidamiento: `position` y `width` son del LAYOUT,
          -- no de la source. Puestos directo acá snacks los IGNORA en silencio —
          -- el árbol quedaba a la izquierda y con 40 columnas por el default del
          -- preset 'sidebar', no por esta config. Verificado en el fuente.
          layout = { layout = { position = 'left', width = 32, min_width = 32 } },
          -- Mostrar archivos ocultos y los ignorados por git: este repo son
          -- puros dotfiles, hay que verlos.
          hidden = true,
          ignored = true,
          -- ...pero `ignored = true` en un proyecto Node te muestra node_modules
          -- ENTERO. Estas exclusiones conservan la utilidad para dotfiles sin
          -- arruinar los repos web. Dentro del árbol, H e I alternan en vivo.
          exclude = { 'node_modules', '.git', '__pycache__', '.venv', '.mypy_cache' },
          -- Seguir el archivo activo: al cambiar de buffer, el árbol lo resalta.
          follow_file = true,
        },
      },
    },
    -- Popups flotantes de entrada de texto (el "Add a new file..." centrado).
    input = {
      enabled = true,
    },

    -- Guías de indentación (las líneas verticales que VSCode muestra siempre) y
    -- resaltado del bloque en el que está el cursor. Reemplaza a indent-blankline:
    -- mismo resultado sin sumar un plugin, porque snacks ya está instalado.
    indent = {
      enabled = true,
      scope = { enabled = true }, -- marcar el bloque actual, no solo los niveles
    },

    -- El "occurrence highlight" de VSCode: al dejar el cursor sobre un símbolo,
    -- resalta todas sus apariciones. Se apoya en textDocument/documentHighlight
    -- del LSP, que ofrecen los 6 servidores del stack (todos menos ruff).
    -- Bonus: ]] y [[ saltan entre apariciones (nativamente no hacen nada útil
    -- fuera de C, así que no se pisa ningún reflejo).
    words = {
      enabled = true,
    },

    -- Columna izquierda unificada: número de línea + signo de git + diagnóstico +
    -- marca de plegado, en un orden fijo y sin pelearse por el espacio.
    statuscolumn = {
      enabled = true,
    },

    -- Scroll suave en vez de saltos de página. Es lo que reemplaza la sensación
    -- de "dónde estoy en el archivo" que otros buscan en un minimapa.
    scroll = {
      enabled = true,
    },
  },
  -- --------------------------------------------------------------------------
  -- Atajos. El grueso son los PICKERS: el motor ya estaba instalado y sano
  -- (rg, fd, git y sqlite disponibles) pero no tenía un solo atajo, así que
  -- faltaba el Ctrl+P entero de VSCode. Todos son con líder, ninguno pisa un
  -- atajo nativo de nvim ni una tecla que se queden Ptyxis/GNOME/Windows Terminal.
  -- --------------------------------------------------------------------------
  keys = {
    { '<leader>e', function() Snacks.explorer() end, desc = 'Explorador de archivos (toggle)' },

    -- El "Ctrl+P" real: mezcla archivos abiertos, recientes y del proyecto,
    -- ordenados por frecuencia de uso. Es el que conviene usar por reflejo.
    { '<leader><space>', function() Snacks.picker.smart() end, desc = 'Buscar archivo (inteligente)' },

    -- Grupo <leader>f = buscar ARCHIVOS y TEXTO (el prefijo que liberó formateo).
    { '<leader>ff', function() Snacks.picker.files() end, desc = 'Buscar: archivos' },
    { '<leader>fg', function() Snacks.picker.grep() end, desc = 'Buscar: texto en el proyecto (grep)' },
    { '<leader>fb', function() Snacks.picker.buffers() end, desc = 'Buscar: buffers abiertos' },
    { '<leader>fr', function() Snacks.picker.recent() end, desc = 'Buscar: archivos recientes' },
    { '<leader>fl', function() Snacks.picker.lines() end, desc = 'Buscar: líneas del archivo actual' },
    -- grep_word funciona en normal (palabra bajo el cursor) y en visual (selección).
    { '<leader>fw', function() Snacks.picker.grep_word() end, desc = 'Buscar: palabra bajo el cursor', mode = { 'n', 'x' } },

    -- Grupo <leader>s = buscar SÍMBOLOS y metadatos del editor.
    { '<leader>ss', function() Snacks.picker.lsp_symbols({ tree = true }) end, desc = 'Símbolos del archivo (outline)' },
    { '<leader>sS', function() Snacks.picker.lsp_workspace_symbols() end, desc = 'Símbolos de todo el proyecto' },
    { '<leader>sd', function() Snacks.picker.diagnostics() end, desc = 'Lista de errores del proyecto' },
    { '<leader>sk', function() Snacks.picker.keymaps() end, desc = 'Atajos de teclado' },
    { '<leader>sh', function() Snacks.picker.help() end, desc = 'Ayuda de nvim (:help)' },

    -- lazygit ya está instalado en el sistema (lo confirma :checkhealth). Cubre
    -- diff/stage/commit completos, que es justo lo que gitsigns no hace.
    { '<leader>gg', function() Snacks.lazygit() end, desc = 'lazygit (git completo)' },
  },
}
