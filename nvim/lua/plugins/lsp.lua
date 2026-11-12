-- ============================================================================
-- lsp.lua — servidores de lenguaje (LSP)
-- ============================================================================
-- mason instala los servidores, mason-lspconfig traduce nombres y nvim-lspconfig aporta
-- cmd/filetypes/root. nvim 0.12 ya trae grn/gra/grr/gri/grt/grx, gO y K: acá solo gd y
-- [d / ]d.
-- ============================================================================

return {
  'neovim/nvim-lspconfig',
  event = { 'BufReadPre', 'BufNewFile' },
  dependencies = {
    { 'mason-org/mason.nvim', opts = {} },
    -- Solo traduce nombres (lua_ls ↔ lua-language-server). automatic_enable = false: si
    -- no, habilita por su cuenta todo lo instalado con Mason.
    { 'mason-org/mason-lspconfig.nvim', opts = { automatic_enable = false } },
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    -- Estado del LSP mientras carga.
    { 'j-hui/fidget.nvim', opts = {} },
    -- Esquemas de SchemaStore.org para jsonls y yamlls.
    'b0o/schemastore.nvim',
  },
  config = function()
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
      callback = function(event)
        local function map(keys, func, desc)
          vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        map('gd', vim.lsp.buf.definition, 'Ir a la definición')
        map('[d', function() vim.diagnostic.jump({ count = -1 }) end, 'Diagnóstico anterior')
        map(']d', function() vim.diagnostic.jump({ count = 1 }) end, 'Diagnóstico siguiente')

        -- Inlay hints solo si el servidor los ofrece; además hay que pedírselos en sus
        -- settings (vtsls y lua_ls, más abajo).
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client:supports_method('textDocument/inlayHint') then
          vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
        end
      end,
    })

    vim.keymap.set('n', '<leader>uh', function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
    end, { desc = 'Alternar inlay hints (tipos en gris)' })

    vim.diagnostic.config({
      severity_sort = true,
      float = { source = 'if_many' },
      underline = true,
      virtual_text = {
        source = 'if_many',
        spacing = 2,
      },
      -- En la línea del cursor, el mensaje completo debajo del código; sin current_line
      -- empuja el archivo entero.
      virtual_lines = { current_line = true },
      signs = vim.g.have_nerd_font and {
        text = {
          [vim.diagnostic.severity.ERROR] = '󰅚 ',
          [vim.diagnostic.severity.WARN]  = '󰀪 ',
          [vim.diagnostic.severity.INFO]  = '󰋽 ',
          [vim.diagnostic.severity.HINT]  = '󰌶 ',
        },
      } or {},
    })

    -- Sin `capabilities`: blink las registra para todos los servidores.
    -- Clave = servidor, valor = su config.
    local servers = {
      -- Los inlay hints vienen apagados en el servidor; typescript y javascript se
      -- configuran por separado.
      vtsls = (function()
        local hints = {
          parameterNames = { enabled = 'all' },
          parameterTypes = { enabled = true },
          variableTypes = { enabled = true },
          functionLikeReturnTypes = { enabled = true },
          propertyDeclarationTypes = { enabled = true },
          enumMemberValues = { enabled = true },
        }
        return {
          settings = {
            typescript = { inlayHints = hints },
            javascript = { inlayHints = hints },
          },
        }
      end)(),
      html = {},
      cssls = {},
      jsonls = {
        settings = {
          json = {
            schemas = require('schemastore').json.schemas(),
            validate = { enable = true },
          },
        },
      },
      yamlls = {
        settings = {
          yaml = {
            -- El schemaStore interno se apaga para que no compita con schemastore.nvim.
            schemaStore = { enable = false, url = '' },
            schemas = require('schemastore').yaml.schemas(),
            -- Sin avisos por claves fuera de orden alfabético.
            keyOrdering = false,
          },
        },
      },
      -- Valida y completa los enlaces entre archivos Markdown.
      marksman = {},
      -- SQL no lleva servidor: sqls necesita un config.yml con la cadena de conexión y
      -- este repo es público.
      dockerls = {},
      docker_compose_language_service = {},
      -- pyright para tipos y navegación; ruff como linter.
      pyright = {},
      ruff = {},
      bashls = {},
      -- La API vim.* la aporta lazydev (lazydev.lua), no diagnostics.globals.
      lua_ls = {
        settings = {
          Lua = {
            completion = { callSnippet = 'Replace' },
            hint = { enable = true },
          },
        },
      },
    }

    -- Además de los servidores, Mason baja los formateadores de formateo.lua.
    local ensure = vim.tbl_keys(servers)
    vim.list_extend(ensure, {
      'shellcheck', -- lo usa bashls
      'stylua',
      'shfmt',
      'prettierd',
      -- Sin dockerfmt: se compila con Go; formatea dockerls.
      'sql-formatter',
    })
    require('mason-tool-installer').setup({ ensure_installed = ensure })

    for name, cfg in pairs(servers) do
      vim.lsp.config(name, cfg)
      vim.lsp.enable(name)
    end
  end,
}
