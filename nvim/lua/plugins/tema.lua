-- ============================================================================
-- tema.lua — colorscheme: "Default Dark Modern" de VSCode (vscode.nvim)
-- ============================================================================
-- Paridad visual con VSCode; por eso se descartaron tokyonight y catppuccin.
-- priority = 1000 y lazy = false: se aplica antes que el resto para que los demás
-- plugins hereden sus colores.
-- ============================================================================

return {
  'Mofiqul/vscode.nvim',
  priority = 1000,
  lazy = false,
  config = function()
    require('vscode').setup({
      -- 'dark' = Dark Modern. (El plugin también trae 'light' por si algún día.)
      style = 'dark',
      -- Sin transparencia: fondo sólido como VSCode real (no el escritorio detrás).
      transparent = false,
      -- Cursiva en comentarios: igual que el tema por defecto de VSCode.
      italic_comments = true,
      -- Subraya los links de markup (@markup.link.*), como VSCode con las URLs.
      -- NO tiene nada que ver con resaltar la palabra bajo el cursor: eso es
      -- documentHighlight del LSP y lo hace snacks.words (ver explorador.lua).
      underline_links = true,
      -- Cursiva en los inlay hints (los tipos inferidos en gris), igual que VSCode.
      italic_inlayhints = true,
    })
    -- Aplicar el tema.
    vim.cmd.colorscheme('vscode')
  end,
}
