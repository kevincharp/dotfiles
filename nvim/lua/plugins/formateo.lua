-- ============================================================================
-- formateo.lua — formateo automático de código (conform.nvim)
-- ============================================================================
-- El "Format on Save" de VSCode: al guardar, ordena el código con el formateador
-- estándar de cada lenguaje (prettier para web, ruff para python, etc.).
--
-- Por qué conform y no el formateo del LSP: conform usa las MISMAS herramientas
-- de línea de comandos que usarías en la terminal o en CI (prettier, shfmt...),
-- así el formato es idéntico dentro y fuera del editor. Se apoya en Mason para
-- instalar esos binarios automáticamente (mismo mecanismo que los servidores LSP).
--
-- Atajo:
--   <leader>f   formatear el archivo a mano (además del automático al guardar)
-- ============================================================================

return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' }, -- carga justo antes de guardar (para el auto-formateo)
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>f',
      function()
        require('conform').format({ async = true, lsp_format = 'fallback' })
      end,
      mode = '',
      desc = 'Formatear archivo',
    },
  },
  opts = {
    -- Formateador por tipo de archivo. conform corre estas herramientas en orden.
    formatters_by_ft = {
      lua = { 'stylua' },
      python = { 'ruff_format' },        -- ruff también formatea (rápido, un solo binario)
      -- Web: prettier para todo el stack front. Si prettierd no está, cae a prettier.
      javascript = { 'prettierd', 'prettier', stop_after_first = true },
      typescript = { 'prettierd', 'prettier', stop_after_first = true },
      typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
      javascriptreact = { 'prettierd', 'prettier', stop_after_first = true },
      html = { 'prettierd', 'prettier', stop_after_first = true },
      css = { 'prettierd', 'prettier', stop_after_first = true },
      json = { 'prettierd', 'prettier', stop_after_first = true },
      yaml = { 'prettierd', 'prettier', stop_after_first = true },
      markdown = { 'prettierd', 'prettier', stop_after_first = true },
      sh = { 'shfmt' },                  -- scripts de shell (bashrc/zshrc del repo)
      bash = { 'shfmt' },
    },

    -- Formatear al guardar (Format on Save).
    format_on_save = function(bufnr)
      -- Lenguajes SIN formateador confiable universal: no forzar formateo al
      -- guardar para no romper archivos ajenos. (Ninguno del stack ahora, pero
      -- deja la puerta abierta a desactivarlo por tipo si hiciera falta.)
      local sin_autoformat = {}
      if sin_autoformat[vim.bo[bufnr].filetype] then
        return
      end
      return { timeout_ms = 500, lsp_format = 'fallback' }
    end,
  },
  init = function()
    -- Permitir formatear con el LSP como respaldo si no hay formateador dedicado.
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
}
