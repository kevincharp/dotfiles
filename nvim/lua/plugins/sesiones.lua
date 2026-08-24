-- ============================================================================
-- sesiones.lua — retomar el proyecto donde lo dejaste (persistence.nvim)
-- ============================================================================
-- Es el "Reopen last workspace" de VSCode. Al salir de nvim guarda la sesión del
-- directorio actual (qué archivos estaban abiertos, en qué ventanas y con qué
-- disposición) y con un atajo la restaura. Una sesión POR PROYECTO, no una sola
-- global: la clave es el directorio desde donde arrancaste nvim.
--
-- Por qué es la pieza que faltaba: el flujo de este repo es abrir la terminal en
-- una carpeta y editar cinco o seis archivos que se referencian entre sí. Sin
-- sesiones, cada `nvim` empieza de cero y hay que volver a buscar los mismos
-- archivos a mano.
--
-- Atajos (grupo <leader>p, "proyecto (sesiones)"):
--   <leader>ps  restaurar la sesión de ESTE directorio
--   <leader>pl  restaurar la ÚLTIMA sesión (venga del directorio que venga)
--   <leader>pp  elegir una sesión de la lista
--   <leader>pd  no guardar la sesión de esta salida (dejarla como estaba)
--
-- Por qué el prefijo <leader>p y no el <leader>q que sugiere el README: acá
-- <leader>q YA es "cerrar ventana" (atajos.lua), y un atajo suelto BLOQUEA todo
-- su prefijo — no puede existir <leader>qs si <leader>q es una acción terminada.
-- Es el mismo motivo por el que el formateo se mudó de <leader>f a <leader>cf.
-- <leader>p estaba libre (verificado sobre los mapeos reales, no sobre memoria).
--
-- La restauración es MANUAL a propósito (no se autocarga al abrir nvim): abrir
-- `nvim archivo.lua` para tocar una línea no tiene que arrastrar diez buffers de
-- la sesión anterior. El guardado sí es automático, que es la parte que uno se
-- olvidaría de hacer.
-- ============================================================================

return {
  'folke/persistence.nvim',
  -- Carga al abrir el primer archivo real: ahí engancha su VimLeavePre para
  -- guardar. Con VeryLazy alcanzaba, pero BufReadPre evita crear sesión cuando
  -- nvim se abrió y cerró sin tocar nada.
  event = 'BufReadPre',
  keys = {
    {
      '<leader>ps',
      function() require('persistence').load() end,
      desc = 'Restaurar la sesión de este directorio',
    },
    {
      '<leader>pl',
      function() require('persistence').load({ last = true }) end,
      desc = 'Restaurar la última sesión',
    },
    {
      '<leader>pp',
      function() require('persistence').select() end,
      desc = 'Elegir una sesión de la lista',
    },
    {
      '<leader>pd',
      function() require('persistence').stop() end,
      desc = 'No guardar la sesión de esta salida',
    },
  },
  opts = {
    -- Una sesión por directorio Y POR RAMA de git. Es lo que uno quiere trabajando
    -- con ramas: los archivos de una feature no son los de main.
    branch = true,
  },
  init = function()
    -- QUÉ se guarda en la sesión. La opción es nativa de vim (:h sessionoptions) y
    -- se setea acá, no en opciones.lua, porque sin este plugin no hace nada.
    -- Respecto del default de nvim se hacen tres cambios:
    --   - se QUITA 'blank': no tiene sentido restaurar ventanas vacías.
    --   - se QUITA 'terminal': restaurar un buffer de terminal deja un shell
    --     muerto (el proceso no sobrevive a la salida). Las terminales se abren
    --     con <leader>tf / <leader>th cuando hacen falta.
    --   - se AGREGAN 'globals' (variables g: que algunos plugins usan para
    --     recordar estado) y 'skiprtp' (no volcar el runtimepath entero en el
    --     archivo de sesión: lo administra lazy.nvim, y guardarlo lo rompe al
    --     restaurar en otra máquina).
    vim.o.sessionoptions = 'buffers,curdir,folds,globals,help,skiprtp,tabpages,winsize'
  end,
}
