-- ============================================================================
-- tema.lua — colorscheme: "Default Dark Modern" de VSCode (vscode.nvim)
-- ============================================================================
-- priority = 1000 y lazy = false: se aplica primero para que los demás plugins hereden
-- sus colores.
-- ============================================================================

return {
  'Mofiqul/vscode.nvim',
  priority = 1000,
  lazy = false,
  config = function()
    require('vscode').setup({
      style = 'dark',
      transparent = false,
      italic_comments = true,
      underline_links = true,
      italic_inlayhints = true,
    })
    vim.cmd.colorscheme('vscode')
  end,
}
