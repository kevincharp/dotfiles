-- ============================================================================
-- esquema.lua — panel de estructura del archivo (aerial) = "Outline" de VSCode
-- ============================================================================
-- Una barra lateral con el índice del archivo: clases, funciones, métodos,
-- variables, anidados y en orden. Se navega con el cursor y salta al símbolo.
--
-- Qué agrega sobre lo que ya había, que se parece pero no es lo mismo:
--   gO            (nativo) tira los símbolos a la lista de ubicaciones: es una
--                 consulta puntual, se cierra al usarla y no muestra jerarquía.
--   <leader>ss    (picker de snacks) busca un símbolo por nombre: perfecto si
--                 sabés qué buscás, inútil para "qué tiene este archivo".
--   aerial        panel PERMANENTE, con la jerarquía dibujada y sincronizado con
--                 el cursor: mientras te movés por el código, resalta dónde estás.
-- Los tres se quedan; son tres usos distintos.
--
-- Igual que dropbar, usa LSP → treesitter → markdown en cascada, así que también
-- da estructura en archivos sin servidor de lenguaje.
--
-- Atajos:
--   <leader>o   abrir / cerrar el panel (queda a la derecha, como en VSCode)
--   Dentro del panel: <Enter> salta al símbolo, o/zo/za despliegan y pliegan.
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
