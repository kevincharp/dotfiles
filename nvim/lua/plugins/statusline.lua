-- ============================================================================
-- statusline.lua — barra de estado inferior (lualine), minimalista
-- ============================================================================
-- Solo el modo a la izquierda, y diagnósticos, posición y reloj a la derecha.
-- ============================================================================

return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  event = 'VeryLazy',
  opts = {
    options = {
      theme = 'auto',
      icons_enabled = vim.g.have_nerd_font,
      component_separators = '',
      section_separators = { left = '', right = '' },
      globalstatus = true, -- una sola barra, no una por split
      -- Sin barra en las ventanas de snacks (lualine no trae extensión para snacks).
      disabled_filetypes = { statusline = { 'snacks_picker_list', 'snacks_picker_input' } },
    },
    sections = {
      lualine_a = { 'mode' },
      lualine_b = {},
      lualine_c = {},
      -- lualine reemplaza la statusline nativa, que ya mostraba los diagnósticos.
      lualine_x = { { 'diagnostics', symbols = { error = '󰅚 ', warn = '󰀪 ', info = '󰋽 ', hint = '󰌶 ' } } },
      lualine_y = { 'location' },
      lualine_z = {
        { function() return ' ' .. vim.fn.strftime('%H:%M') end },
      },
    },
    extensions = { 'toggleterm', 'lazy', 'mason', 'quickfix' },
  },
}
