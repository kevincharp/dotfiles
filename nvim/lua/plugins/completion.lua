-- ============================================================================
-- autocompletado.lua — menú de autocompletado (blink.cmp)
-- ============================================================================
-- Preset 'default': <C-n>/<C-p> navegan, <C-y> acepta, <C-e> cierra. <C-space> no llega
-- a nvim en Linux: es el atajo global de Ulauncher.
-- ============================================================================

return {
  'saghen/blink.cmp',
  -- blink registra sus capabilities antes de que arranquen los servidores LSP.
  event = { 'BufReadPre', 'BufNewFile' },
  version = '1.*', -- release estable, con el binario precompilado
  dependencies = {
    'rafamadriz/friendly-snippets',
  },
  opts = {
    keymap = { preset = 'default' },

    appearance = {
      nerd_font_variant = 'mono',
    },

    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 300 },
    },

    -- Firma de la función al escribir los argumentos; viene apagada por defecto.
    signature = { enabled = true },

    -- lazydev aporta la API vim.*; el score_offset la pone arriba de lo que da lua_ls.
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer', 'lazydev' },
      providers = {
        lazydev = { name = 'LazyDev', module = 'lazydev.integrations.blink', score_offset = 100 },
      },
    },

    fuzzy = { implementation = 'prefer_rust_with_warning' },
  },
}
