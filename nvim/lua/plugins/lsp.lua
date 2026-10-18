-- ============================================================================
-- lsp.lua — servidores de lenguaje (LSP)
-- ============================================================================
-- mason instala los servidores (en ~/.local/share/nvim/mason), mason-lspconfig
-- traduce nombres y nvim-lspconfig aporta cmd/filetypes/root. API nueva
-- (vim.lsp.config + vim.lsp.enable). nvim 0.12 ya trae grn/gra/grr/gri/grt/grx,
-- gO, K y <C-w>d: acá solo gd (definición del LSP) y [d / ]d.
-- ============================================================================

return {
  'neovim/nvim-lspconfig',
  event = { 'BufReadPre', 'BufNewFile' },
  dependencies = {
    -- Mason: baja los binarios de los servidores. OJO con el nombre de la org:
    -- el proyecto se mudó de `williamboman/` a `mason-org/`. La URL vieja todavía
    -- resuelve por el redirect de GitHub, pero conviene no depender de eso.
    { 'mason-org/mason.nvim', opts = {} },
    -- mason-lspconfig va SOLO por el mapeo de nombres: los servidores se llaman
    -- `html`/`cssls`/`lua_ls` en lspconfig pero `html-lsp`/`css-lsp`/`lua-language-server`
    -- como paquetes de Mason, y este plugin es el que traduce (lo que hace que la
    -- lista `ensure` de abajo funcione con nombres de servidor).
    -- automatic_enable = false es IMPRESCINDIBLE: su default es true, y entonces
    -- llama vim.lsp.enable() por su cuenta para TODO lo instalado con Mason —
    -- chocaría con el bucle explícito del final y arrancaría servidores que hayas
    -- bajado solo para probar con :Mason.
    { 'mason-org/mason-lspconfig.nvim', opts = { automatic_enable = false } },
    -- Instala automáticamente las herramientas listadas si faltan.
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    -- Mensajes de estado del LSP mientras carga (esquina, discreto).
    { 'j-hui/fidget.nvim', opts = {} },
    -- Catálogo de esquemas JSON/YAML de SchemaStore.org (el mismo que usa VSCode).
    -- Es solo datos, sin binarios: lo consumen jsonls y yamlls más abajo.
    'b0o/schemastore.nvim',
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
        map('[d', function() vim.diagnostic.jump({ count = -1 }) end, 'Diagnóstico anterior')
        map(']d', function() vim.diagnostic.jump({ count = 1 }) end, 'Diagnóstico siguiente')

        -- INLAY HINTS: los tipos inferidos y nombres de parámetros en gris que
        -- VSCode muestra de fábrica en TypeScript. Se prenden por buffer y solo si
        -- el servidor los ofrece (del stack: vtsls y lua_ls sí; pyright NO).
        -- OJO, hacen falta DOS cosas: esto, y pedirle al servidor que los genere
        -- (ver los settings de vtsls y lua_ls más abajo). Sin lo segundo, el
        -- servidor contesta una lista vacía y no se ve nada.
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client:supports_method('textDocument/inlayHint') then
          vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
        end
      end,
    })

    -- Alternar los inlay hints: son muy útiles leyendo código ajeno y molestos
    -- cuando estás escribiendo una línea larga, así que conviene poder apagarlos.
    vim.keymap.set('n', '<leader>uh', function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
    end, { desc = 'Alternar inlay hints (tipos en gris)' })

    -- ---------------------------------------------------------------------
    -- Cómo se ven los diagnósticos (errores/avisos) en pantalla.
    -- ---------------------------------------------------------------------
    vim.diagnostic.config({
      severity_sort = true,               -- ordenar por gravedad
      float = { source = 'if_many' },     -- el borde lo pone winborder (opciones.lua)
      underline = true,                   -- subrayar el código con problema
      -- Texto corto al final de la línea, para el resto de las líneas.
      virtual_text = {
        source = 'if_many',
        spacing = 2,
      },
      -- Y en la línea DEL CURSOR, el mensaje completo desplegado abajo del código.
      -- Es lo que resuelve los errores largos de TypeScript ("Type 'string' is not
      -- assignable to...") que con virtual_text se cortan contra el borde derecho.
      -- `current_line = true` es clave: sin eso, virtual_lines empuja el archivo
      -- entero y se vuelve ilegible.
      virtual_lines = { current_line = true },
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
    -- No hace falta pasar `capabilities`: desde nvim 0.11 blink las registra solo
    -- con vim.lsp.config('*', {...}) para todos los servidores.
    -- ---------------------------------------------------------------------
    -- Servidores del stack (Web, Python, Bash, Lua): clave = nombre, valor = settings.
    -- ---------------------------------------------------------------------
    local servers = {
      -- Web: TypeScript/JavaScript/React. vtsls es el wrapper moderno de tsserver.
      -- Los inlayHints vienen TODOS apagados del lado del servidor: sin este bloque
      -- vim.lsp.inlay_hint.enable() no muestra nada (verificado: el servidor
      -- contesta `textDocument/inlayHint → {}`). Hay que declararlo dos veces,
      -- para typescript y para javascript, porque vtsls los trata por separado.
      vtsls = (function()
        local hints = {
          parameterNames = { enabled = 'all' },      -- nombre del argumento en la llamada
          parameterTypes = { enabled = true },       -- tipo de cada parámetro
          variableTypes = { enabled = true },        -- tipo inferido de las variables
          functionLikeReturnTypes = { enabled = true }, -- tipo de retorno inferido
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
      -- HTML y CSS.
      html = {},
      cssls = {},
      -- JSON y YAML con ESQUEMAS. Es la pieza que faltaba y que más se nota:
      -- editando package.json, tsconfig.json, un workflow de GitHub Actions o un
      -- docker-compose.yml, el servidor sabe qué claves existen, las autocompleta,
      -- muestra su documentación al pasar el cursor y marca en rojo lo que no es
      -- válido — exactamente lo que hace VSCode, y por la misma fuente
      -- (SchemaStore.org). Sin esto, un .json era texto con colores nada más.
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
            -- El schemaStore INTERNO de yamlls hay que apagarlo: si queda
            -- prendido, compite con el catálogo de schemastore.nvim y gana el que
            -- responde primero (esquemas distintos para el mismo archivo).
            schemaStore = { enable = false, url = '' },
            schemas = require('schemastore').yaml.schemas(),
            -- keyOrdering viene en `true` y avisa por cada clave "fuera de orden
            -- alfabético": ruido puro en archivos ajenos.
            keyOrdering = false,
          },
        },
      },
      -- Markdown: marksman entiende el documento como documento, no como texto.
      -- Completa y valida los enlaces internos ([[wiki]] y [texto](./archivo.md)),
      -- avisa si apuntan a un archivo o a un encabezado que no existe, y da
      -- ir-a-la-definición sobre un enlace. Es justo lo que hace falta con los
      -- CLAUDE.md, los README y los docs/ de este repo, que se referencian entre sí.
      marksman = {},
      -- SQL no lleva servidor a propósito: sqls necesita un config.yml con la cadena
      -- de conexión y este repo es público. Resaltado y formateo: treesitter.lua y
      -- formateo.lua.
      -- Docker: dockerls (Dockerfile) y docker_compose_language_service (compose);
      -- el compose recibe además yamlls por el filetype 'yaml.docker-compose'
      -- (ver lua/tipos-archivo.lua).
      dockerls = {},
      docker_compose_language_service = {},
      -- Python: pyright (tipos/navegación) + ruff (linter rápido; formateo va en conform).
      pyright = {},
      ruff = {},
      -- Bash: para los scripts del repo (bashrc/zshrc). Usa shellcheck si está.
      bashls = {},
      -- Lua: para editar la propia config de nvim. Quién le enseña la API 'vim' es
      -- lazydev (ver lazydev.lua), NO un `diagnostics.globals = {'vim'}` acá: ese
      -- parche solo silenciaba el aviso y dejaba sin completado ni hover de vim.*.
      lua_ls = {
        settings = {
          Lua = {
            completion = { callSnippet = 'Replace' },
            -- Inlay hints también en Lua (tipos de parámetro y de variable).
            hint = { enable = true },
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
      -- NO se pone 'dockerfmt': Mason lo instala compilando un paquete de Go y en
      -- esta máquina no hay toolchain de Go (verificado: "Could not find
      -- executable go in PATH"). Tampoco hace falta: dockerls ya ofrece
      -- textDocument/formatting, y conform lo usa por su lsp_format = 'fallback'.
      'sql-formatter', -- formateo de consultas .sql (npm, no necesita Go)
      -- prettier (a secas) y ruff ya vienen: ruff es servidor LSP + formateador.
    })
    require('mason-tool-installer').setup({ ensure_installed = ensure })

    -- Arrancar cada servidor con su config. La API nueva (nvim 0.11+) es
    -- vim.lsp.config + enable, más simple que el setup viejo de lspconfig.
    for name, cfg in pairs(servers) do
      vim.lsp.config(name, cfg)
      vim.lsp.enable(name)
    end
  end,
}
