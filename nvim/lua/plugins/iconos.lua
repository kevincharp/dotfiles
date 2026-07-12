-- ============================================================================
-- iconos.lua — íconos por tipo de archivo (Nerd Font)
-- ============================================================================
-- nvim-web-devicons provee los glifos que ves en el árbol de archivos, la
-- statusline, el finder, etc. (el iconito de .ts, .lua, .json...). Requiere una
-- Nerd Font en la terminal: ya tenés FiraCode Nerd Font instalada y activa en
-- Ptyxis/Windows Terminal, así que renderizan bien.
--
-- No necesita config: otros plugins (neo-tree, lualine) lo cargan como dependencia.
-- Lo dejamos como spec propia para que quede explícito y con lazy = false.
-- ============================================================================

return {
  'nvim-tree/nvim-web-devicons',
  lazy = false,
}
