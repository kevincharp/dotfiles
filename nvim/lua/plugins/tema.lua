-- ============================================================================
-- tema.lua — colorscheme: réplica exacta del "Default Dark Modern" de VSCode
-- ============================================================================
-- Mofiqul/vscode.nvim reproduce los colores del tema por defecto de VSCode
-- (Dark Modern) pixel por pixel. Elegido a propósito para que nvim se vea igual
-- que VSCode. Alternativas más "bonitas pero distintas" (tokyonight, catppuccin)
-- se descartaron: acá el objetivo es paridad visual con VSCode.
--
-- priority = 1000 → se carga ANTES que el resto (un tema debe aplicarse primero
-- para que los demás plugins hereden sus colores). lazy = false → al arranque.
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
      -- Subrayar la palabra bajo el cursor cuando el LSP la resuelve (llega en etapa LSP).
      underline_links = true,
      -- Colorear la columna de signos (git/diagnósticos) acorde al fondo.
      disable_nvimtree_bg = true,
    })
    -- Aplicar el tema.
    vim.cmd.colorscheme('vscode')
  end,
}
