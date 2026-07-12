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
--   <leader>hb     ver blame de la línea (quién y cuándo la tocó)
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
      map('n', '<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame de la línea')
    end,
  },
}
