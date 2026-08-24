-- ============================================================================
-- autocompletado.lua — menú de autocompletado (blink.cmp)
-- ============================================================================
-- El popup de sugerencias de VSCode mientras escribís: completa símbolos del
-- LSP, palabras del buffer, rutas de archivos y snippets. blink.cmp es el motor
-- moderno de nvim 0.12 (rápido, en Rust) — el que usan configs actuales.
--
-- Cómo se maneja (preset 'default', estilo nvim idiomático):
--   <C-space>   abrir/cerrar el menú — OJO: en LINUX esta tecla NO LLEGA a nvim.
--               Ctrl+Space es el atajo global de Ulauncher (gnome/media-keys.dconf,
--               custom1) y GNOME la captura antes. Usá <C-n>/<C-p>, que además
--               abren el menú si estaba cerrado. En Windows sí funciona.
--   <C-n>/<C-p> siguiente / anterior sugerencia (y abren el menú)
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
  -- Carga al ABRIR un archivo, no al empezar a escribir. Antes decía
  -- 'InsertEnter', pero era letra muerta: blink registra sus capabilities de LSP
  -- desde su plugin/, y eso tiene que pasar ANTES de que arranquen los servidores
  -- (BufReadPre). Declararlo así hace explícito el momento real de carga.
  event = { 'BufReadPre', 'BufNewFile' },
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

    -- Firma de la función mientras escribís los argumentos: al abrir el paréntesis
    -- aparecen los parámetros y se resalta en cuál estás. Es lo que VSCode hace
    -- solo. Viene APAGADO por defecto en blink; existe el nativo <C-s> en insert,
    -- pero es a demanda y el automático es el que cambia la experiencia.
    signature = { enabled = true },

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
