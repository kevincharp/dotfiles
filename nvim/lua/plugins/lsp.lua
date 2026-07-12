-- ============================================================================
-- lsp.lua — servidores de lenguaje (LSP): el "cerebro" tipo IDE
-- ============================================================================
-- El LSP (Language Server Protocol) es lo que hace que VSCode "entienda" el
-- código: ir a la definición, ver errores mientras escribís, documentación al
-- pasar el cursor (hover), renombrar símbolos en todo el proyecto, autocompletar.
--
-- Piezas:
--   mason.nvim            → instala los servidores (binarios) automáticamente
--   mason-lspconfig       → puente entre Mason y lspconfig (instala lo que falte)
--   nvim-lspconfig        → configura y arranca cada servidor
--
-- Los servidores se instalan en el data-dir (~/.local/share/nvim/mason), FUERA
-- del repo. NOTA: Mason baja binarios de internet; algunos necesitan node (ya lo
-- tenés). En Windows detrás de proxy corporativo puede fallar alguno (ver CLAUDE.md).
--
-- Atajos LSP (se activan SOLO en buffers con servidor adjunto, vía on_attach):
--   gd          ir a la definición        gr   ver referencias
--   gI          ir a la implementación     K    hover (documentación)
--   <leader>rn  renombrar símbolo          <leader>ca  acciones de código (quick fix)
--   <leader>d   ver el error/diagnóstico de la línea   [d / ]d  saltar entre errores
-- ============================================================================

return {
  'neovim/nvim-lspconfig',
  event = { 'BufReadPre', 'BufNewFile' },
  dependencies = {
    -- Mason y su puente con lspconfig (instalan los servidores solos).
    { 'williamboman/mason.nvim', opts = {} },
    'williamboman/mason-lspconfig.nvim',
    -- Instala automáticamente las herramientas listadas si faltan.
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    -- Mensajes de estado del LSP mientras carga (esquina, discreto).
    { 'j-hui/fidget.nvim', opts = {} },
  },
  config = function()
    -- ---------------------------------------------------------------------
    -- Acciones al ADJUNTAR un servidor a un buffer: acá viven los atajos LSP.
    -- Se disparan solo cuando hay un servidor activo para ese archivo.
    -- ---------------------------------------------------------------------
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
      callback = function(event)
        local function map(keys, func, desc)
          vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        map('gd', vim.lsp.buf.definition, 'Ir a la definición')
        map('gr', vim.lsp.buf.references, 'Ver referencias')
        map('gI', vim.lsp.buf.implementation, 'Ir a la implementación')
        map('K', vim.lsp.buf.hover, 'Documentación (hover)')
        map('<leader>rn', vim.lsp.buf.rename, 'Renombrar símbolo')
        map('<leader>ca', vim.lsp.buf.code_action, 'Acciones de código (quick fix)')
        map('<leader>d', vim.diagnostic.open_float, 'Ver diagnóstico de la línea')
        map('[d', function() vim.diagnostic.jump({ count = -1 }) end, 'Diagnóstico anterior')
        map(']d', function() vim.diagnostic.jump({ count = 1 }) end, 'Diagnóstico siguiente')
      end,
    })

    -- ---------------------------------------------------------------------
    -- Cómo se ven los diagnósticos (errores/avisos) en pantalla.
    -- ---------------------------------------------------------------------
    vim.diagnostic.config({
      severity_sort = true,               -- ordenar por gravedad
      float = { border = 'rounded', source = 'if_many' },
      underline = true,                   -- subrayar el código con problema
      virtual_text = {                    -- texto del error al final de la línea
        source = 'if_many',
        spacing = 2,
      },
      -- Íconos en la columna de signos (Nerd Font).
      signs = vim.g.have_nerd_font and {
        text = {
          [vim.diagnostic.severity.ERROR] = '󰅚 ',
          [vim.diagnostic.severity.WARN]  = '󰀪 ',
          [vim.diagnostic.severity.INFO]  = '󰋽 ',
          [vim.diagnostic.severity.HINT]  = '󰌶 ',
        },
      } or {},
    })

    -- ---------------------------------------------------------------------
    -- Capacidades: le avisamos al servidor qué puede hacer el cliente. Se
    -- amplían con las de blink.cmp (autocompletado) — ver autocompletado.lua.
    -- ---------------------------------------------------------------------
    local capabilities = require('blink.cmp').get_lsp_capabilities()

    -- ---------------------------------------------------------------------
    -- Servidores del stack decidido (Web, Python, Bash, Lua). La clave es el
    -- nombre del servidor; el valor, su config (settings específicos).
    -- ---------------------------------------------------------------------
    local servers = {
      -- Web: TypeScript/JavaScript/React. vtsls es el wrapper moderno de tsserver.
      vtsls = {},
      -- HTML y CSS.
      html = {},
      cssls = {},
      -- Python: pyright (tipos/navegación) + ruff (linter rápido; formateo va en conform).
      pyright = {},
      ruff = {},
      -- Bash: para los scripts del repo (bashrc/zshrc). Usa shellcheck si está.
      bashls = {},
      -- Lua: para editar la propia config de nvim. Le avisamos de la API 'vim'.
      lua_ls = {
        settings = {
          Lua = {
            completion = { callSnippet = 'Replace' },
            -- Evita el aviso "variable global vim no definida" al configurar nvim.
            diagnostics = { globals = { 'vim' } },
          },
        },
      },
    }

    -- Lista de herramientas para que Mason instale automáticamente: servidores
    -- de arriba + shellcheck (para bashls) + los formateadores que usa conform
    -- (formateo.lua). Los tenemos acá centralizados porque Mason es quien baja
    -- todos los binarios (servidores y formateadores) por igual.
    local ensure = vim.tbl_keys(servers)
    vim.list_extend(ensure, {
      'shellcheck', -- linter de shell (lo usa bashls)
      'stylua',     -- formateo de Lua
      'shfmt',      -- formateo de shell/bash
      'prettierd',  -- formateo web (JS/TS/HTML/CSS/JSON/YAML/MD), demonio rápido
      -- prettier (a secas) y ruff ya vienen: ruff es servidor LSP + formateador.
    })
    require('mason-tool-installer').setup({ ensure_installed = ensure })

    -- Arrancar cada servidor con las capabilities y su config. La API nueva
    -- (nvim 0.11+) es vim.lsp.config + enable, más simple que el setup viejo.
    for name, cfg in pairs(servers) do
      cfg.capabilities = capabilities
      vim.lsp.config(name, cfg)
      vim.lsp.enable(name)
    end
  end,
}
