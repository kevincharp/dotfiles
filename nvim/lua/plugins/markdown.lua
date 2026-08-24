-- ============================================================================
-- markdown.lua — Markdown legible dentro del editor (render-markdown)
-- ============================================================================
-- Este repo es casi todo Markdown (CLAUDE.md, README, docs/), así que valía la
-- pena. Dibuja el documento EN EL BUFFER: los `#` se vuelven encabezados con
-- fondo, las viñetas `-` un •, los `---` una línea completa, las tablas quedan
-- alineadas con bordes, los bloques de código con su lenguaje y su marco, y las
-- casillas `- [ ]` / `- [x]` con íconos.
--
-- Por qué render-markdown y no markview.nvim (el otro candidato serio):
-- el ANTI-CONCEAL. Los dos ocultan la sintaxis para que se lea lindo, pero
-- render-markdown la MUESTRA DE VUELTA en la línea donde está el cursor. O sea
-- que lees el documento renderizado y editás el markdown crudo, sin apagar nada.
-- Es la diferencia entre un visor y algo con lo que se puede trabajar.
--
-- No es una preview en el navegador ni un panel aparte: es el mismo buffer, así
-- que el cursor, la búsqueda y los atajos siguen siendo los de siempre.
--
-- Y NO agrega atajos, así que no hay nada que pueda chocar. Los comandos son
-- :RenderMarkdown enable / disable / toggle si alguna vez molesta.
-- ============================================================================

return {
  'MeanderingProgrammer/render-markdown.nvim',
  ft = { 'markdown' },
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons',
  },
  opts = {
    -- En qué modos se dibuja. 'n' y 'c' (normal y línea de comandos) pero NO 'i':
    -- escribiendo, el markdown crudo es más predecible.
    render_modes = { 'n', 'c' },
    -- Mostrar la sintaxis real en la línea del cursor (lo que gana a markview).
    anti_conceal = { enabled = true },
    heading = {
      -- Fondo de color por nivel de encabezado, como un documento de verdad.
      width = 'block',
      -- Encabezados con ancho de bloque, no de toda la ventana: en una pantalla
      -- ancha, una barra de color de 200 columnas para un `## título` es ruido.
      min_width = 40,
    },
    code = {
      -- Marco alrededor de los bloques ``` con el lenguaje arriba.
      width = 'block',
      min_width = 45,
      border = 'thin',
    },
    -- Las tablas de este repo son anchas; alinearlas es media pelea ganada.
    pipe_table = { preset = 'round' },
  },
  init = function()
    -- Opciones que tiene que tener un buffer de Markdown para que esto se vea bien
    -- y para que escribir prosa sea cómodo. Van BUFFER-LOCAL en un autocmd, no
    -- globales: `wrap` en un archivo de código parte las líneas largas al medio y
    -- `conceallevel` esconde sintaxis en cualquier lenguaje.
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'markdown',
      group = vim.api.nvim_create_augroup('markdown-opciones', { clear = true }),
      callback = function()
        -- `conceallevel` NO se toca acá a propósito: render-markdown lo administra
        -- solo (lo sube a 3 mientras dibuja y lo devuelve al salir del buffer;
        -- verificado). Ponerlo a mano era pelearle al plugin por la misma opción.
        vim.opt_local.wrap = true       -- la prosa se envuelve, no se corta
        vim.opt_local.linebreak = true  -- y envuelve entre palabras, no en la mitad
        -- Con wrap activo, j/k saltan el párrafo entero (son líneas "lógicas").
        -- Estos mapeos los hacen moverse por línea VISUAL, que es lo que uno
        -- espera escribiendo texto. Solo en este buffer: en código, j/k siguen
        -- siendo los nativos exactos.
        vim.keymap.set({ 'n', 'v' }, 'j', 'gj', { buffer = true, desc = 'Bajar una línea visual' })
        vim.keymap.set({ 'n', 'v' }, 'k', 'gk', { buffer = true, desc = 'Subir una línea visual' })
      end,
    })
  end,
}
