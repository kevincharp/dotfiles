-- ============================================================================
-- pares.lua — cerrar paréntesis, comillas y etiquetas solo
-- ============================================================================
-- nvim-autopairs para (), [], {} y comillas; nvim-ts-autotag para etiquetas HTML/JSX.
-- ============================================================================

return {
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = {
      -- treesitter decide, según el nodo, si corresponde emparejar comillas.
      check_ts = true,
      ts_config = {
        -- Nodos donde no se emparejan.
        lua = { 'string' },
        javascript = { 'string', 'template_string' },
        typescript = { 'string', 'template_string' },
      },
      -- Alt+e envuelve la palabra siguiente en el par.
      fast_wrap = { map = '<M-e>' },
      enable_check_bracket_line = true,
    },
  },
  {
    'windwp/nvim-ts-autotag',
    ft = {
      'html', 'xml', 'javascript', 'javascriptreact',
      'typescript', 'typescriptreact', 'svelte', 'vue', 'markdown',
    },
    opts = {
      opts = {
        enable_close = true,
        enable_rename = true, -- renombra el cierre al cambiar la apertura
        enable_close_on_slash = false,
      },
    },
  },
}
