-- ============================================================================
-- statusline.lua — barra de estado inferior (lualine), estilo MINIMALISTA
-- ============================================================================
-- Versión limpia, inspirada en el setup que nos gustó: solo el modo a la
-- izquierda y posición + reloj a la derecha. El centro queda vacío a propósito
-- (menos ruido). Toma los colores del tema activo (vscode.nvim) vía theme='auto'.
--
-- Antes teníamos una barra "cargada" (git + diff + nombre + diagnósticos +
-- tipo). Se simplificó a pedido: preferencia por lo prolijo sobre lo informativo.
-- ============================================================================

return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  event = 'VeryLazy',
  opts = {
    options = {
      theme = 'auto',               -- hereda los colores de vscode.nvim
      icons_enabled = vim.g.have_nerd_font,
      component_separators = '',    -- sin separadores internos (más limpio)
      section_separators = { left = '', right = '' }, -- sin separadores en los extremos tampoco
      globalstatus = true,          -- UNA sola statusline para todo (no una por split)
      -- No dibujar la barra dentro de las ventanas de snacks: si no, ahí aparece
      -- el buffer del picker como si fuera un archivo abierto. NO existe extensión
      -- de lualine para snacks (sí para neo-tree, que ya no usamos), así que la
      -- vía real son estos filetypes, tomados del fuente de snacks.
      disabled_filetypes = { statusline = { 'snacks_picker_list', 'snacks_picker_input' } },
    },
    sections = {
      -- Izquierda: solo el modo (NORMAL / INSERT / VISUAL...).
      lualine_a = { 'mode' },
      lualine_b = {},
      lualine_c = {},                                    -- CENTRO VACÍO (a propósito)
      -- Derecha: contador de errores/avisos, posición en el archivo y reloj.
      -- El contador es la única concesión al minimalismo: la statusline NATIVA de
      -- 0.12 muestra vim.diagnostic.status() por defecto y lualine la reemplaza,
      -- así que sin esto perdíamos información que antes venía gratis.
      lualine_x = { { 'diagnostics', symbols = { error = '󰅚 ', warn = '󰀪 ', info = '󰋽 ', hint = '󰌶 ' } } },
      lualine_y = { 'location' },                        -- línea:columna
      lualine_z = {
        -- Reloj con la hora actual (como en el screenshot). El %H:%M lo resuelve
        -- vim.fn.strftime en cada refresco de la barra.
        { function() return ' ' .. vim.fn.strftime('%H:%M') end },
      },
    },
    -- Extensiones: barras a medida para ventanas de plugins (en vez del nombre de
    -- buffer crudo). Solo las de plugins que realmente tenemos instalados.
    extensions = { 'toggleterm', 'lazy', 'mason', 'quickfix' },
  },
}
