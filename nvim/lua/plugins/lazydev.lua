-- ============================================================================
-- lazydev.lua — tipos de la API de nvim al editar la propia config
-- ============================================================================
-- Completado, hover y definición de vim.* en lua_ls, sin el aviso "undefined global
-- vim".
-- ============================================================================

return {
  'folke/lazydev.nvim',
  ft = 'lua',
  opts = {
    library = {
      -- Tipos de vim.uv, solo si el archivo lo menciona.
      { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
    },
  },
}
