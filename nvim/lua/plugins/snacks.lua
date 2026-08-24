-- ============================================================================
-- snacks.lua — colección de módulos de folke (explorador, pickers, ayudas visuales)
-- ============================================================================
-- ANTES este archivo se llamaba explorador.lua, porque de snacks solo usábamos el
-- árbol de archivos. Se renombró cuando pasó a cubrir varias cosas: snacks es UN
-- plugin con muchos módulos, y la regla del repo es un archivo por plugin (partir
-- sus `opts` en dos archivos funciona pero deja la config con dos cabezas).
--
-- Módulos ACTIVADOS acá y qué dan (todos venían en disco, apagados):
--   explorer     → el árbol de archivos lateral izquierdo (el "Explorer" de VSCode)
--   picker       → buscador flotante: archivos, grep, símbolos… (ver buscador.lua)
--   input        → los popups de entrada de texto ("Add a new file" centrado)
--   indent       → guías verticales de indentación + resaltado del bloque actual
--   words        → resalta TODAS las apariciones de la palabra bajo el cursor
--   statuscolumn → junta número + signo de git + diagnóstico + plegado, prolijo
--   scroll       → scroll suave (ayuda a no perder de vista dónde estabas)
--
-- Los que siguen apagados a propósito: image (Ptyxis no soporta el protocolo
-- gráfico de kitty — ver CLAUDE.md), dashboard, notifier, zen, dim.
--
-- El árbol se abre/cierra con <leader>e (toggle). Dentro del árbol:
--   <Enter>  abrir           a  crear archivo/carpeta (popup flotante)
--   d        borrar          r  renombrar    m  mover
--   c / p    copiar / pegar  H / I  alternar ocultos / ignorados    ?  ayuda
--   /        filtrar (la barra '>' de arriba)
-- ============================================================================

return {
  'folke/snacks.nvim',
  priority = 1000, -- carga temprano (varios módulos deben estar listos al inicio)
  lazy = false,
  opts = {
    -- Árbol de archivos lateral. La posición y el ancho imitan al Explorer de VSCode.
    explorer = {
      enabled = true,
    },
    -- Motor de selección flotante (lo usan el filtro del árbol y los pickers).
    picker = {
      enabled = true,
      sources = {
        explorer = {
          -- OJO con el nivel de anidamiento: `position` y `width` son del LAYOUT,
          -- no de la source. Puestos directo acá snacks los IGNORA en silencio —
          -- el árbol quedaba a la izquierda y con 40 columnas por el default del
          -- preset 'sidebar', no por esta config. Verificado en el fuente.
          layout = { layout = { position = 'left', width = 32, min_width = 32 } },
          -- Mostrar archivos ocultos y los ignorados por git: este repo son
          -- puros dotfiles, hay que verlos.
          hidden = true,
          ignored = true,
          -- ...pero `ignored = true` en un proyecto Node te muestra node_modules
          -- ENTERO. Estas exclusiones conservan la utilidad para dotfiles sin
          -- arruinar los repos web. Dentro del árbol, H e I alternan en vivo.
          exclude = { 'node_modules', '.git', '__pycache__', '.venv', '.mypy_cache' },
          -- Seguir el archivo activo: al cambiar de buffer, el árbol lo resalta.
          follow_file = true,
        },
      },
    },
    -- Popups flotantes de entrada de texto (el "Add a new file..." centrado).
    input = {
      enabled = true,
    },

    -- Guías de indentación (las líneas verticales que VSCode muestra siempre) y
    -- resaltado del bloque en el que está el cursor. Reemplaza a indent-blankline:
    -- mismo resultado sin sumar un plugin, porque snacks ya está instalado.
    indent = {
      enabled = true,
      scope = { enabled = true }, -- marcar el bloque actual, no solo los niveles
    },

    -- El "occurrence highlight" de VSCode: al dejar el cursor sobre un símbolo,
    -- resalta todas sus apariciones. Se apoya en textDocument/documentHighlight
    -- del LSP, que ofrecen los 6 servidores del stack (todos menos ruff).
    -- Bonus: ]] y [[ saltan entre apariciones (nativamente no hacen nada útil
    -- fuera de C, así que no se pisa ningún reflejo).
    words = {
      enabled = true,
    },

    -- Columna izquierda unificada: número de línea + signo de git + diagnóstico +
    -- marca de plegado, en un orden fijo y sin pelearse por el espacio.
    statuscolumn = {
      enabled = true,
    },

    -- Scroll suave en vez de saltos de página. Es lo que reemplaza la sensación
    -- de "dónde estoy en el archivo" que otros buscan en un minimapa.
    scroll = {
      enabled = true,
    },
  },
  keys = {
    { '<leader>e', function() Snacks.explorer() end, desc = 'Explorador de archivos (toggle)' },
  },
}
