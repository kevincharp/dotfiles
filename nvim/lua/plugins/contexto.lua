-- ============================================================================
-- contexto.lua — sticky scroll: la función en la que estás, fija arriba
-- ============================================================================
-- Complementa a dropbar (ruta) mostrando el código real de las líneas que abren
-- el bloque. Solo se mapea <leader>uc (mostrar/ocultar): `[c` es nativo (diff).
-- ============================================================================

return {
  'nvim-treesitter/nvim-treesitter-context',
  event = { 'BufReadPost', 'BufNewFile' },
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  keys = {
    -- OJO con el nombre del comando: NO es :TSContextToggle (eso era la API vieja
    -- y hoy tira "E492: No es una orden del editor", verificado). Hoy hay un solo
    -- comando :TSContext con subcomandos (enable/disable/toggle). Se llama a la
    -- función directo para no depender de cómo se llame el comando mañana.
    {
      '<leader>uc',
      function() require('treesitter-context').toggle() end,
      desc = 'Alternar contexto fijo (sticky scroll)',
    },
  },
  opts = {
    -- Cuántas líneas de contexto como máximo. 3 alcanza para
    -- clase → método → if sin comerse media pantalla.
    max_lines = 3,
    -- No mostrar contexto si la ventana es muy baja: ahí las 3 líneas serían la
    -- mitad del área visible y estorban más de lo que ayudan.
    min_window_height = 20,
    -- Línea separadora entre el contexto y el código. Sin esto cuesta ver dónde
    -- termina lo fijo y empieza el buffer real (el contexto usa el mismo fondo).
    separator = '─',
    -- De qué línea se calcula el contexto. 'cursor' = de la línea DEL CURSOR;
    -- 'topline' = de la primera línea visible. Con 'topline' el encabezado no
    -- cambia mientras movés el cursor por la pantalla, pero tampoco te dice en
    -- qué bloque estás parado, que es justamente para lo que sirve.
    mode = 'cursor',
  },
}
