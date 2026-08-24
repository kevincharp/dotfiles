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
--   <leader>cf  formatear el archivo a mano (además del automático al guardar)
--
-- OJO, esto ANTES era <leader>f. Se mudó a <leader>cf (grupo "código") porque
-- <leader>f como atajo suelto BLOQUEA todo el prefijo: no puede existir un
-- <leader>ff ni un <leader>fg si <leader>f ya es una acción terminada. Ese
-- prefijo ahora es el grupo "buscar" de los pickers (ver snacks.lua).
-- ============================================================================

return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' }, -- carga justo antes de guardar (para el auto-formateo)
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
    -- Formateador por tipo de archivo. conform corre estas herramientas en orden.
    formatters_by_ft = {
      lua = { 'stylua' },
      python = { 'ruff_format' },        -- ruff también formatea (rápido, un solo binario)
      -- Web: prettier para todo el stack front. La cadena cae a `prettier` si
      -- `prettierd` falla — pero OJO: prettier a secas NO está instalado (Mason
      -- solo baja prettierd), así que hoy ese respaldo es teórico. Se deja porque
      -- engancha solo si algún día hay un prettier del proyecto en node_modules.
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
      -- Los Dockerfile NO se listan a propósito: el formateador de la comunidad
      -- (dockerfmt) se compila con Go y acá no hay toolchain de Go. Al no tener
      -- entrada, conform cae al LSP por su lsp_format = 'fallback' y formatea con
      -- dockerls, que sí ofrece textDocument/formatting (verificado).
      -- Los compose son YAML: los formatea prettier. El filetype es compuesto
      -- ('yaml.docker-compose', ver lua/tipos-archivo.lua) y conform resuelve por
      -- el filetype ENTERO, así que hay que nombrarlo tal cual.
      ['yaml.docker-compose'] = { 'prettierd', 'prettier', stop_after_first = true },
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
