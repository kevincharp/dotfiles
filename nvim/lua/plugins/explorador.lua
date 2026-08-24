-- ============================================================================
-- explorador.lua — árbol de archivos a la izquierda (snacks.nvim explorer)
-- ============================================================================
-- El "Explorer" tipo VSCode, con la estética del setup que nos gustó: barra de
-- filtro arriba ('>' para buscar en el árbol) y popup FLOTANTE centrado al crear
-- archivos ("Add a new file..."). Usa snacks.nvim (de folke), que reemplazó al
-- neo-tree que teníamos: mismo rol (árbol lateral izquierdo), estética más pulida.
--
-- snacks es una colección de mini-módulos; acá activamos solo:
--   explorer → el árbol de archivos
--   picker   → el motor de selección flotante que usan el filtro y los diálogos
--   input    → los popups flotantes (el "Add a new file" centrado)
-- El resto de módulos de snacks quedan apagados (no molestan).
--
-- Se abre/cierra con <leader>e (toggle). Dentro del árbol:
--   <Enter>  abrir           a  crear archivo/carpeta (popup flotante)
--   d        borrar          r  renombrar    m  mover
--   c / p    copiar / pegar  H  mostrar/ocultar ocultos    ?  ayuda
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
  },
  keys = {
    { '<leader>e', function() Snacks.explorer() end, desc = 'Explorador de archivos (toggle)' },
  },
}
