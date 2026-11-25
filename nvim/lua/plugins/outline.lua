-- ============================================================================
-- esquema.lua — panel de estructura del archivo (aerial)
-- ============================================================================
-- <leader>o abre el panel; dentro, <Enter> salta y o/zo/za despliegan y pliegan.
-- ============================================================================

return {
  'stevearc/aerial.nvim',
  cmd = { 'AerialToggle', 'AerialOpen', 'AerialNavToggle' },
  keys = {
    { '<leader>o', '<cmd>AerialToggle<CR>', desc = 'Esquema del archivo (outline)' },
  },
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons',
  },
  opts = {
    -- A la derecha: el explorador ocupa la izquierda.
    layout = {
      default_direction = 'right',
      min_width = 30,
      placement = 'window',
    },
    -- Todos los tipos de símbolo: el filtro por defecto deja casi vacío un archivo Lua.
    filter_kind = false,
    show_guides = true,
    highlight_on_jump = 300,
    autojump = false,
    close_on_select = false,
  },
}
