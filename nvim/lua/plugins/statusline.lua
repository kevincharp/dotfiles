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
      section_separators = { left = '', right = '' }, -- separadores "flecha" en los extremos
      globalstatus = true,          -- UNA sola statusline para todo (no una por split)
    },
    sections = {
      -- Izquierda: solo el modo (NORMAL / INSERT / VISUAL...).
      lualine_a = { 'mode' },
      lualine_b = {},
      lualine_c = {},                                    -- CENTRO VACÍO (a propósito)
      -- Derecha: cantidad de buffers, posición en el archivo y reloj.
      lualine_x = {},
      lualine_y = { 'location' },                        -- línea:columna
      lualine_z = {
        -- Reloj con la hora actual (como en el screenshot). El %H:%M lo resuelve
        -- vim.fn.strftime en cada refresco de la barra.
        { function() return ' ' .. vim.fn.strftime('%H:%M') end },
      },
    },
    -- Cuando lualine no logra tema, evita romper: 'auto' ya lo cubre.
    -- Extensiones: integra la barra con la ventana de snacks para que ahí no
    -- aparezca "snacks"/"neo-tree" como nombre de archivo colgando.
    extensions = {},
  },
}
