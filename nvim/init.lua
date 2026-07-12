-- ============================================================================
-- init.lua — punto de entrada de la config de Neovim
-- ============================================================================
-- Config portable (Linux + Windows) basada en el modelo de kickstart.nvim:
-- cada plugin vive en su propio archivo dentro de lua/plugins/ y lazy.nvim los
-- descubre solos. Para sumar un plugin nuevo: creá un archivo ahí. Para sacarlo:
-- borralo. Nada de capas ocultas.
--
-- Orden de carga:
--   1. líder (debe fijarse ANTES de cargar plugins, si no los atajos no toman)
--   2. opciones  (comportamiento base del editor)
--   3. atajos    (mapeos nativos; los de estilo VSCode se sumarán más adelante)
--   4. lazy.nvim (gestor de plugins) → carga todo lua/plugins/
-- ============================================================================

-- La tecla líder ("<leader>") es el prefijo de los atajos propios. Espacio es
-- el estándar moderno de nvim (y el default de kickstart/LazyVim). Se fija acá,
-- lo más temprano posible, porque los plugins leen su valor al registrarse.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Damos por hecho que hay una Nerd Font en la terminal (FiraCode Nerd Font, ya
-- instalada y usada por Ptyxis/Windows Terminal). Habilita íconos en los plugins.
vim.g.have_nerd_font = true

-- Configuración base del editor y atajos nativos (archivos en lua/).
require('opciones')
require('atajos')

-- Gestor de plugins (lazy.nvim). Debe ir al final: adentro descubre y carga
-- todo lo que haya en lua/plugins/.
require('gestor')
