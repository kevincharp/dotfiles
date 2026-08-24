-- ============================================================================
-- pestanas.lua — pestañas de archivos abiertos (bufferline)
-- ============================================================================
-- La barra de pestañas de VSCode arriba: un tab por archivo abierto, con ícono,
-- nombre, marca de "modificado" y contador de errores del LSP. En vim los
-- archivos abiertos son "buffers" y viven invisibles (`:ls`); esto los hace
-- visibles, que es la pieza que más se extraña viniendo de un editor gráfico.
--
-- Por qué bufferline y no barbar: bufferline es el que replica el look de VSCode
-- (separadores finos, diagnósticos en el tab, "offset" para no montarse sobre el
-- explorador). Su repo tiene poco movimiento porque está terminado, no
-- abandonado: funciona en 0.12 sin avisos de deprecación (verificado).
--
-- ATAJOS — se investigó cada uno antes de mapearlo:
--   ]b / [b        siguiente / anterior pestaña. NO es un mapeo nuevo: ]b y [b
--                  YA son nativos de nvim 0.11+ (:bnext / :bprevious). Se
--                  REDEFINEN al equivalente de bufferline por una sola razón:
--                  los nativos van por NÚMERO de buffer, así que si movés una
--                  pestaña de lugar, "siguiente" deja de ser la de la derecha.
--                  Misma semántica, orden visual correcto.
--   <leader>1..9   ir directo a la pestaña N (el Alt+1..9 de VSCode NO se puede:
--                  Ptyxis usa Alt+1..9 para SUS pestañas y las captura antes de
--                  que lleguen a nvim; en Windows Terminal, Alt+número es lo
--                  mismo). <leader>N no choca con nada: los dígitos con líder
--                  estaban libres, y como líder es espacio no se confunde con
--                  un contador de vim.
--   <leader>bd     cerrar la pestaña SIN cerrar la ventana (el `:bd` pelado te
--                  deja el split vacío o cierra nvim; esto usa Snacks.bufdelete)
--   <leader>bo     cerrar todas menos la actual
--   <leader>bp     fijar (pin) la pestaña, para que no se cierre con <leader>bo
--   <leader>b< / > mover la pestaña a la izquierda / derecha
-- (Si hay tantos archivos abiertos que la barra no alcanza, la lista completa
-- está en <leader>fb, el picker de buffers de snacks.)
-- Deliberadamente NO se usan Shift+H / Shift+L (el atajo típico de las configs
-- de moda): pisan H y L nativos, que son "ir al tope / al pie de la pantalla".
-- Tampoco Ctrl+PageUp/PageDown: los toma la terminal para sus propias pestañas.
-- ============================================================================

return {
  'akinsho/bufferline.nvim',
  event = 'VeryLazy',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  keys = {
    { ']b', '<cmd>BufferLineCycleNext<CR>', desc = 'Pestaña siguiente' },
    { '[b', '<cmd>BufferLineCyclePrev<CR>', desc = 'Pestaña anterior' },
    { '<leader>bd', function() Snacks.bufdelete() end, desc = 'Cerrar pestaña (sin cerrar la ventana)' },
    { '<leader>bo', function() Snacks.bufdelete.other() end, desc = 'Cerrar las otras pestañas' },
    { '<leader>bp', '<cmd>BufferLineTogglePin<CR>', desc = 'Fijar / soltar la pestaña' },
    { '<leader>b>', '<cmd>BufferLineMoveNext<CR>', desc = 'Mover la pestaña a la derecha' },
    { '<leader>b<', '<cmd>BufferLineMovePrev<CR>', desc = 'Mover la pestaña a la izquierda' },
  },
  opts = {
    options = {
      -- 'buffers' = un tab por archivo abierto (lo de VSCode). El otro modo,
      -- 'tabs', usa las tabpages de vim, que son grupos de ventanas: otra cosa.
      mode = 'buffers',
      -- Errores/avisos del LSP dentro del tab, como los puntitos de VSCode.
      diagnostics = 'nvim_lsp',
      diagnostics_indicator = function(_, _, diag)
        local iconos = { error = '󰅚 ', warning = '󰀪 ' }
        local partes = {}
        if diag.error then table.insert(partes, iconos.error .. diag.error) end
        if diag.warning then table.insert(partes, iconos.warning .. diag.warning) end
        return table.concat(partes, ' ')
      end,
      -- La X para cerrar con el mouse tiene que borrar el buffer sin tocar el
      -- layout (mismo motivo que <leader>bd).
      close_command = function(n) Snacks.bufdelete(n) end,
      right_mouse_command = function(n) Snacks.bufdelete(n) end,
      -- Corre la barra a la derecha mientras el explorador está abierto, para que
      -- las pestañas no queden montadas encima de él. El filetype es el de la
      -- lista del picker de snacks (el explorador ES un picker, ver snacks.lua).
      offsets = {
        {
          filetype = 'snacks_picker_list',
          text = 'Explorador',
          highlight = 'Directory',
          separator = true,
        },
      },
      separator_style = 'thin',
      show_buffer_close_icons = true,
      show_close_icon = false,       -- la X global de "cerrar todo" no hace falta
      always_show_bufferline = true, -- mostrar la barra aun con un solo archivo
      -- Un archivo nuevo se abre JUSTO A LA DERECHA del actual, no al final de la
      -- fila: así "ir a la definición" en otro archivo lo deja al lado del que
      -- venías leyendo. Es el orden que usa VSCode.
      sort_by = 'insert_after_current',
    },
  },
  config = function(_, opts)
    require('bufferline').setup(opts)
    -- Ir directo a la pestaña N. Se generan en el bucle para no repetir 9 líneas
    -- iguales; van acá y no en `keys` porque son mapeos triviales y el plugin ya
    -- está cargado en este punto.
    for i = 1, 9 do
      vim.keymap.set('n', '<leader>' .. i, function()
        require('bufferline').go_to(i, true)
      end, { desc = 'Ir a la pestaña ' .. i })
    end
  end,
}
