-- ============================================================================
-- breadcrumbs.lua — ruta del símbolo actual arriba del archivo (dropbar)
-- ============================================================================
-- <leader>; activa el modo pick; el click abre el menú del tramo (requiere
-- mousemoveevent, en opciones.lua).
-- ============================================================================

return {
  'Bekaboo/dropbar.nvim',
  event = { 'BufReadPost', 'BufNewFile' },
  keys = {
    { '<leader>;', function() require('dropbar.api').pick() end, desc = 'Elegir un tramo de la ruta (breadcrumbs)' },
  },
  opts = {
    bar = {
      -- Sin barra en los paneles de plugins, que dropbar ve como buffers reales.
      enable = function(buf, win, _)
        if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
          return false
        end
        local ft = vim.bo[buf].filetype
        local excluidos = {
          ['snacks_picker_list'] = true,
          ['snacks_picker_input'] = true,
          ['grug-far'] = true,
          ['lazy'] = true,
          ['mason'] = true,
          ['help'] = true,
        }
        if excluidos[ft] then return false end
        return vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= ''
      end,
    },
    menu = {
      win_configs = { border = vim.o.winborder },
    },
  },
}
