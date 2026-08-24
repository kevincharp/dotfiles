-- ============================================================================
-- contexto.lua — "sticky scroll": la función en la que estás, fija arriba
-- ============================================================================
-- Es el Sticky Scroll de VSCode. Al bajar por una función larga, las líneas que
-- abren el bloque (la firma de la función, el `if`, el `for`) quedan CLAVADAS en
-- la primera línea de la ventana en vez de irse por arriba. Sirve para no perder
-- de vista en qué estás cuando el cuerpo no entra en pantalla.
--
-- Se complementa con dropbar (breadcrumbs.lua) sin pisarse: dropbar vive en el
-- winbar y muestra la RUTA completa (archivo › clase › método) en una línea;
-- esto muestra el CÓDIGO REAL de las líneas que abrieron el bloque, con su
-- resaltado, encima del buffer. Uno responde "dónde estoy" y el otro "qué dice
-- la firma que ya no veo".
--
-- No agrega ningún atajo por su cuenta. Los que sugiere su README serían un
-- problema: propone `[c` para saltar al contexto, y `[c` es NATIVO de vim
-- (saltar al cambio anterior en modo diff, :h [c). Acá solo se mapea el toggle,
-- en el grupo de alternar:
--   <leader>uc  mostrar / ocultar el contexto fijo
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
