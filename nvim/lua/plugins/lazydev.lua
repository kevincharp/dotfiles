-- ============================================================================
-- lazydev.lua — tipos de la API de nvim al editar la propia config
-- ============================================================================
-- Evita el aviso "undefined global vim" de lua_ls y da completado, hover y
-- definición de vim.api/vim.opt/vim.lsp, cargando los tipos on demand.
-- ============================================================================

return {
  'folke/lazydev.nvim',
  ft = 'lua', -- solo hace falta editando Lua
  opts = {
    library = {
      -- Tipos de luv (vim.uv): las llamadas asíncronas de nvim. `words` le dice a
      -- lazydev que cargue esta librería solo si el archivo menciona vim.uv.
      { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
    },
  },
}
