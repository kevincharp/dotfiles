-- ============================================================================
-- formateo.lua — formateo automático al guardar (conform.nvim)
-- ============================================================================
-- Formateadores instalados vía Mason (lsp.lua). <leader>cf y no <leader>f: un atajo
-- suelto bloquearía el grupo "buscar".
-- ============================================================================

return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>cf',
      function()
        require('conform').format({ async = true, lsp_format = 'fallback' })
      end,
      mode = '',
      desc = 'Formatear archivo',
    },
  },
  opts = {
    formatters_by_ft = {
      lua = { 'stylua' },
      python = { 'ruff_format' },
      -- prettier solo entra si el proyecto lo trae en node_modules; Mason baja
      -- prettierd.
      javascript = { 'prettierd', 'prettier', stop_after_first = true },
      typescript = { 'prettierd', 'prettier', stop_after_first = true },
      typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
      javascriptreact = { 'prettierd', 'prettier', stop_after_first = true },
      html = { 'prettierd', 'prettier', stop_after_first = true },
      css = { 'prettierd', 'prettier', stop_after_first = true },
      json = { 'prettierd', 'prettier', stop_after_first = true },
      yaml = { 'prettierd', 'prettier', stop_after_first = true },
      markdown = { 'prettierd', 'prettier', stop_after_first = true },
      sh = { 'shfmt' },
      bash = { 'shfmt' },
      -- Sin entrada para Dockerfile: lo formatea dockerls por lsp_format = 'fallback'.
      -- conform resuelve por el filetype entero, por eso el compose se nombra tal cual.
      ['yaml.docker-compose'] = { 'prettierd', 'prettier', stop_after_first = true },
      sql = { 'sql_formatter' },
      mysql = { 'sql_formatter' },
      plsql = { 'sql_formatter' },
    },

    format_on_save = { timeout_ms = 500, lsp_format = 'fallback' },
  },
  init = function()
    -- gq formatea con conform.
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
}
