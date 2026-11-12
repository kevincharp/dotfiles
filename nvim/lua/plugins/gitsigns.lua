-- ============================================================================
-- gitsigns.lua — marcas de git en la columna de signos
-- ============================================================================
-- Atajos bajo <leader>h; text object ih para el hunk.
-- ============================================================================

return {
  'lewis6991/gitsigns.nvim',
  event = { 'BufReadPre', 'BufNewFile' },
  opts = {
    signs = {
      add          = { text = '│' },
      change       = { text = '│' },
      delete       = { text = '_' },
      topdelete    = { text = '‾' },
      changedelete = { text = '~' },
      untracked    = { text = '┆' },
    },
    -- Blame al final de la línea del cursor; <leader>hB lo alterna.
    current_line_blame = true,
    current_line_blame_opts = { delay = 300, virt_text_pos = 'eol' },
    on_attach = function(bufnr)
      local gs = require('gitsigns')
      local function map(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
      end

      map('n', ']c', function() gs.nav_hunk('next') end, 'Siguiente cambio (git)')
      map('n', '[c', function() gs.nav_hunk('prev') end, 'Cambio anterior (git)')

      map('n', '<leader>hp', gs.preview_hunk, 'Previsualizar cambio (hunk)')
      map('n', '<leader>hs', gs.stage_hunk, 'Stage del hunk')
      map('n', '<leader>hr', gs.reset_hunk, 'Revertir el hunk')
      map('n', '<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame de la línea (popup)')

      map('v', '<leader>hs', function() gs.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') }) end, 'Stage de la selección')
      map('v', '<leader>hr', function() gs.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') }) end, 'Revertir la selección')

      map('n', '<leader>hd', gs.diffthis, 'Diff contra HEAD')
      map('n', '<leader>hD', function() gs.diffthis('~') end, 'Diff contra el commit anterior')

      map('n', '<leader>hB', gs.toggle_current_line_blame, 'Alternar blame inline')

      map({ 'o', 'x' }, 'ih', gs.select_hunk, 'Hunk de git (text object)')
    end,
  },
}
