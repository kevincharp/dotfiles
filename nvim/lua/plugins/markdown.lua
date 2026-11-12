-- ============================================================================
-- markdown.lua — Markdown legible dentro del editor (render-markdown)
-- ============================================================================
-- Dibuja el documento en el buffer y deja el markdown crudo en la línea del cursor.
-- :RenderMarkdown toggle lo apaga.
-- ============================================================================

return {
  'MeanderingProgrammer/render-markdown.nvim',
  ft = { 'markdown' },
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons',
  },
  opts = {
    -- No en insert: escribiendo, el markdown crudo es más predecible.
    render_modes = { 'n', 'c' },
    anti_conceal = { enabled = true },
    heading = {
      -- Ancho del texto, no de toda la ventana.
      width = 'block',
      min_width = 40,
    },
    code = {
      width = 'block',
      min_width = 45,
      border = 'thin',
    },
    pipe_table = { preset = 'round' },
  },
  init = function()
    -- Locales al buffer: en código, wrap partiría las líneas largas.
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'markdown',
      group = vim.api.nvim_create_augroup('markdown-opciones', { clear = true }),
      callback = function()
        -- conceallevel lo administra render-markdown.
        vim.opt_local.wrap = true
        vim.opt_local.linebreak = true -- corta entre palabras
        -- Con wrap, j/k se mueven por línea visual.
        vim.keymap.set({ 'n', 'v' }, 'j', 'gj', { buffer = true, desc = 'Bajar una línea visual' })
        vim.keymap.set({ 'n', 'v' }, 'k', 'gk', { buffer = true, desc = 'Subir una línea visual' })
      end,
    })
  end,
}
