-- ============================================================================
-- lazydev.lua — tipos de la API de nvim al editar la propia config
-- ============================================================================
-- Problema que resuelve: al escribir Lua para nvim, lua_ls no sabe qué es `vim` y
-- avisa "undefined global vim" en cada línea. El parche fácil es declararlo como
-- global conocido (así estaba en lsp.lua), pero eso solo CALLA el aviso: seguís
-- sin completado, sin hover y sin ir-a-la-definición de vim.api/vim.opt/vim.lsp.
-- Y justo eso es el caso de uso más frecuente en este repo.
--
-- La alternativa que documenta kickstart es cargarle a lua_ls TODO el runtimepath
-- como librería, pero su propio comentario avisa que es "a lot slower and will
-- cause issues when working on your own configuration" (issue nvim-lspconfig#3189).
--
-- lazydev carga los tipos ON DEMAND, según lo que el archivo realmente requiere.
-- Solo se activa en archivos .lua, no trae binarios y es del mismo autor que
-- snacks/which-key (folke), así que encaja con el resto del stack.
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
