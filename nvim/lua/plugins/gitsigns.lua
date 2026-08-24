-- ============================================================================
-- gitsigns.lua — marcas de git en la columna de signos
-- ============================================================================
-- El "gutter" de git de VSCode: en la columna izquierda marca qué líneas se
-- añadieron (│ verde), modificaron (│ azul) o borraron (‾ rojo) respecto al
-- último commit. También permite navegar entre cambios y ver/revertir hunks.
--
-- Atajos (con líder, grupo <leader>h = "hunk"):
--   ]c / [c        saltar al siguiente / anterior cambio
--   <leader>hp     previsualizar el cambio (hunk) bajo el cursor
--   <leader>hs     stage del hunk      <leader>hr  revertir el hunk
--                  (en modo visual, solo las líneas seleccionadas)
--   <leader>hb     ver blame de la línea en popup (mensaje de commit completo)
--   <leader>hB     alternar el blame INLINE (el gris al final de la línea)
--   <leader>hd     diff del archivo contra HEAD   <leader>hD  contra HEAD~
--   ih             text object del hunk: `dih` borra el cambio, `vih` lo marca
-- ============================================================================

return {
  'lewis6991/gitsigns.nvim',
  event = { 'BufReadPre', 'BufNewFile' }, -- carga al abrir un archivo
  opts = {
    signs = {
      add          = { text = '│' },
      change       = { text = '│' },
      delete       = { text = '_' },
      topdelete    = { text = '‾' },
      changedelete = { text = '~' },
      untracked    = { text = '┆' },
    },
    -- Blame INLINE: al final de la línea del cursor, en gris, quién la tocó y
    -- cuándo. Es el "GitLens lite" de VSCode y no cuesta un plugin extra.
    -- Se alterna con <leader>hB porque leyendo código ajeno ayuda y escribiendo
    -- distrae.
    current_line_blame = true,
    current_line_blame_opts = { delay = 300, virt_text_pos = 'eol' },
    on_attach = function(bufnr)
      local gs = require('gitsigns')
      local function map(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
      end

      -- Navegar entre cambios.
      map('n', ']c', function() gs.nav_hunk('next') end, 'Siguiente cambio (git)')
      map('n', '[c', function() gs.nav_hunk('prev') end, 'Cambio anterior (git)')

      -- Acciones sobre hunks (prefijo <leader>h).
      map('n', '<leader>hp', gs.preview_hunk, 'Previsualizar cambio (hunk)')
      map('n', '<leader>hs', gs.stage_hunk, 'Stage del hunk')
      map('n', '<leader>hr', gs.reset_hunk, 'Revertir el hunk')
      map('n', '<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame de la línea (popup)')

      -- Stage / revertir solo las líneas SELECCIONADAS (no el hunk entero).
      map('v', '<leader>hs', function() gs.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') }) end, 'Stage de la selección')
      map('v', '<leader>hr', function() gs.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') }) end, 'Revertir la selección')

      -- Diff del archivo contra HEAD y contra el commit anterior.
      map('n', '<leader>hd', gs.diffthis, 'Diff contra HEAD')
      map('n', '<leader>hD', function() gs.diffthis('~') end, 'Diff contra el commit anterior')

      -- Alternar el blame inline (el texto gris al final de la línea).
      map('n', '<leader>hB', gs.toggle_current_line_blame, 'Alternar blame inline')

      -- Text object del hunk: `dih` borra el cambio, `vih` lo selecciona.
      map({ 'o', 'x' }, 'ih', gs.select_hunk, 'Hunk de git (text object)')
    end,
  },
}
