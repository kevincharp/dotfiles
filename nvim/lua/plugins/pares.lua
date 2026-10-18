-- ============================================================================
-- pares.lua — cerrar paréntesis, comillas y etiquetas solo
-- ============================================================================
-- nvim-autopairs para (), [], {} y comillas; nvim-ts-autotag para HTML/JSX/Vue.
-- Salta el cierre existente y no cierra antes de una letra. <M-e> envuelve la
-- palabra bajo el cursor (fast_wrap). Sin atajos nuevos.
-- ============================================================================

return {
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = {
      -- Preguntarle a treesitter en qué nodo está el cursor antes de aplicar las
      -- reglas de comillas (ver la nota del encabezado: no afecta a los corchetes).
      check_ts = true,
      ts_config = {
        -- Nodos donde NO se emparejan comillas, por lenguaje: adentro de un string
        -- o de un template string de JS, `"` va sola.
        lua = { 'string' },
        javascript = { 'string', 'template_string' },
        typescript = { 'string', 'template_string' },
      },
      -- Envolver la palabra siguiente en el par, con Alt+e.
      fast_wrap = { map = '<M-e>' },
      -- No cerrar si lo que sigue es una letra o un dígito: escribiendo `(` al
      -- principio de `algo` querés `(algo`, no `()algo`.
      enable_check_bracket_line = true,
    },
  },
  {
    -- Etiquetas de HTML/JSX: cierra </div> y renombra el par al editar una punta.
    'windwp/nvim-ts-autotag',
    ft = {
      'html', 'xml', 'javascript', 'javascriptreact',
      'typescript', 'typescriptreact', 'svelte', 'vue', 'markdown',
    },
    opts = {
      opts = {
        enable_close = true,          -- cerrar la etiqueta al escribir `>`
        enable_rename = true,         -- renombrar la de cierre al cambiar la de apertura
        enable_close_on_slash = false, -- `</` NO autocompleta: molesta más que ayuda
      },
    },
  },
}
