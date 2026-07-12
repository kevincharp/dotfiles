-- ============================================================================
-- autocompletado.lua — menú de autocompletado (blink.cmp)
-- ============================================================================
-- El popup de sugerencias de VSCode mientras escribís: completa símbolos del
-- LSP, palabras del buffer, rutas de archivos y snippets. blink.cmp es el motor
-- moderno de nvim 0.12 (rápido, en Rust) — el que usan configs actuales.
--
-- Cómo se maneja (preset 'default', estilo nvim idiomático):
--   <C-space>   abrir/cerrar el menú de sugerencias
--   <C-n>/<C-p> siguiente / anterior sugerencia
--   <C-y>       ACEPTAR la sugerencia seleccionada
--   <C-e>       cerrar el menú
--   <Tab>       saltar al siguiente campo del snippet (una vez expandido)
--
-- Nota: se eligió el preset 'default' (aceptar con <C-y>) en vez del típico
-- <Enter>/<Tab> de VSCode, para no pisar reflejos de vim mientras aprendés lo
-- nativo. Los atajos estilo VSCode se ajustarán en la etapa de keymaps.
-- ============================================================================

return {
  'saghen/blink.cmp',
  event = 'InsertEnter', -- carga al empezar a escribir
  version = '1.*',        -- release estable (trae el binario Rust precompilado)
  dependencies = {
    -- Colección de snippets lista para varios lenguajes.
    'rafamadriz/friendly-snippets',
  },
  opts = {
    keymap = { preset = 'default' },

    appearance = {
      -- Usar íconos de Nerd Font en el menú (tipos de sugerencia).
      nerd_font_variant = 'mono',
    },

    completion = {
      -- Mostrar la documentación de la sugerencia en un popup al lado,
      -- automáticamente tras una breve pausa (como VSCode).
      documentation = { auto_show = true, auto_show_delay_ms = 300 },
    },

    -- Fuentes de sugerencias, por prioridad: LSP, rutas, snippets, buffer.
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer' },
    },

    -- Motor de fuzzy matching. 'prefer_rust_with_warning': usa el binario Rust
    -- (rápido) y avisa si tuviera que caer al de Lua. Viene precompilado con la
    -- versión fijada, así que no requiere compilar nada.
    fuzzy = { implementation = 'prefer_rust_with_warning' },
  },
}
