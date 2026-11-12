-- ============================================================================
-- init.lua — punto de entrada de la config de Neovim
-- ============================================================================
-- Un archivo por plugin en lua/plugins/. El líder se fija antes de cargar los
-- plugins porque leen su valor al registrarse.
-- ============================================================================

vim.g.mapleader = ' '
-- Distinto del líder: un <localleader>x de un plugin pisaría un <space>x global.
vim.g.maplocalleader = '\\'

-- Habilita los íconos de los plugins (FiraCode Nerd Font en la terminal).
vim.g.have_nerd_font = true

require('opciones')
require('atajos')
require('tipos-archivo')

-- Al final: lazy.nvim carga todo lua/plugins/.
require('gestor')
