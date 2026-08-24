-- ============================================================================
-- breadcrumbs.lua — la ruta del símbolo actual arriba del archivo (dropbar)
-- ============================================================================
-- Los "breadcrumbs" de VSCode: una línea arriba de la ventana que dice dónde
-- estás parado, no solo en qué archivo. Por ejemplo:
--   nvim  lua  plugins  breadcrumbs.lua  󰡱 setup  󰊕 callback
-- Sirve leyendo archivos largos, donde el nombre de la función que te contiene
-- quedó 200 líneas más arriba.
--
-- Se eligió dropbar y no nvim-navic porque navic mete la ruta en la STATUSLINE,
-- y la statusline de esta config es minimalista a propósito (ver statusline.lua).
-- dropbar usa la WINBAR: es por ventana, así que con dos splits cada uno muestra
-- su propia ruta, que es justo lo que hace VSCode.
--
-- Fuentes de la ruta, en orden: LSP (símbolos reales) → treesitter → indentación.
-- O sea que funciona igual en un archivo sin servidor de lenguaje, con menos
-- precisión. No hay nada que configurar para eso, es el default.
--
-- Atajos:
--   <leader>;   modo "pick": pone una letra sobre cada tramo de la ruta y con esa
--               tecla saltás ahí (o abrís el menú desplegable de ese nivel).
--   Con el mouse: click en un tramo abre su menú de hermanos. Requiere
--               mousemoveevent, que ya está prendido en opciones.lua.
-- ============================================================================

return {
  'Bekaboo/dropbar.nvim',
  event = { 'BufReadPost', 'BufNewFile' },
  keys = {
    { '<leader>;', function() require('dropbar.api').pick() end, desc = 'Elegir un tramo de la ruta (breadcrumbs)' },
  },
  opts = {
    bar = {
      -- Qué ventanas llevan la barra. El default ya excluye buffers sin archivo,
      -- pero hay que sumar a mano los del stack: el explorador y el panel de
      -- buscar/reemplazar son buffers "reales" para dropbar y no tiene sentido
      -- ponerles una ruta de símbolos.
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
    -- El menú desplegable respeta winborder (opciones.lua) para verse igual que
    -- el resto de los flotantes.
    menu = {
      win_configs = { border = vim.o.winborder },
    },
  },
}
