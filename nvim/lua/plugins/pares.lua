-- ============================================================================
-- pares.lua — cerrar paréntesis, comillas y etiquetas solo (autopairs)
-- ============================================================================
-- Lo que VSCode hace de fábrica y en nvim pelado no pasa: escribís `(` y aparece
-- `()` con el cursor en el medio; escribís `<div>` y se cierra `</div>`. Son dos
-- plugins porque son dos problemas distintos:
--   nvim-autopairs   → (), [], {}, '', "", `` en cualquier lenguaje
--   nvim-ts-autotag  → etiquetas de HTML/JSX/Vue (necesita treesitter para saber
--                      qué es una etiqueta y qué es un operador `<`)
--
-- Por qué NO molesta (es el miedo razonable con estos plugins). Los tres puntos
-- están VERIFICADOS con teclas simuladas, no supuestos:
--   - Si el cursor ya tiene el cierre delante, escribir `)` SALTA sobre él en vez
--     de duplicarlo (`f(a|)` + `)` queda `f(a)`, no `f(a))`).
--   - No cierra si lo que sigue es una letra o un dígito: poniendo `(` delante de
--     `algo` querés `(algo`, no `()algo`. Esta es la regla que de verdad lo
--     mantiene fuera del camino, y aplica en cualquier parte del archivo.
--   - `check_ts` sirve para las COMILLAS, no para los corchetes: dentro de un
--     string, `"` inserta una sola comilla (cerrar la de al lado sería absurdo);
--     en código inserta el par. OJO con la expectativa: un `(` SÍ se cierra
--     también dentro de un string o de un comentario — autopairs no discrimina
--     para los corchetes, y en la práctica no molesta por la regla anterior.
--   - `fast_wrap` (<M-e>): con el cursor pegado a una palabra, la envuelve en el
--     par en vez de insertarlo. Alt+e no lo toma ni Ptyxis ni Windows Terminal
--     (Ptyxis se queda Alt+1..9 y las de menú; verificado en atajos.lua).
--
-- No hay atajos nuevos que puedan chocar: esto actúa sobre teclas que ya escribís
-- en modo insert.
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
