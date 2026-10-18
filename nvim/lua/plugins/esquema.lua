-- ============================================================================
-- esquema.lua — panel de estructura del archivo (aerial)
-- ============================================================================
-- Panel permanente con la jerarquía de símbolos, sincronizado con el cursor.
-- Convive con gO (consulta puntual) y <leader>ss (buscar por nombre).
-- <leader>o lo abre/cierra; dentro: <Enter> salta, o/zo/za despliegan y pliegan.
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
    -- A la derecha: el explorador de snacks ya ocupa la izquierda, y así se
    -- pueden tener los dos abiertos como en VSCode.
    layout = {
      default_direction = 'right',
      min_width = 30,
      -- 'window' = split normal, no un flotante: no tapa el código.
      placement = 'window',
    },
    -- Mostrar TODOS los tipos de símbolo. El default de aerial filtra a
    -- Class/Constructor/Enum/Function/Interface/Module/Struct, que en un archivo
    -- de config Lua (tablas y variables) deja el panel casi vacío.
    filter_kind = false,
    -- Las líneas ├─ │ que dibujan el anidamiento.
    show_guides = true,
    -- Resaltar en el panel el símbolo donde está el cursor, y seguirlo mientras
    -- te movés por el código. Es la mitad de la utilidad del panel.
    highlight_on_jump = 300,
    autojump = false, -- moverse por el panel NO mueve el código hasta apretar Enter
    -- Cerrar el panel automáticamente al saltar a un símbolo sería lo contrario a
    -- lo que hace VSCode (el Outline queda abierto), así que se deja abierto.
    close_on_select = false,
  },
}
