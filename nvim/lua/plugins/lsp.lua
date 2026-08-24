-- ============================================================================
-- lsp.lua — servidores de lenguaje (LSP): el "cerebro" tipo IDE
-- ============================================================================
-- El LSP (Language Server Protocol) es lo que hace que VSCode "entienda" el
-- código: ir a la definición, ver errores mientras escribís, documentación al
-- pasar el cursor (hover), renombrar símbolos en todo el proyecto, autocompletar.
--
-- Piezas:
--   mason.nvim            → instala los servidores (binarios) automáticamente
--   mason-lspconfig       → traduce nombres de servidor ↔ nombres de paquete Mason
--   nvim-lspconfig        → aporta el cmd/filetypes/root de cada servidor
--
-- Sobre nvim-lspconfig: su "framework" viejo (require('lspconfig')) está DEPRECADO,
-- pero el plugin NO — sigue siendo la fuente de los archivos lsp/*.lua con cómo se
-- invoca cada servidor y cómo se detecta la raíz del proyecto. Esta config ya usa
-- la API nueva (vim.lsp.config + vim.lsp.enable) y no lo requiere en ningún lado.
--
-- Los servidores se instalan en el data-dir (~/.local/share/nvim/mason), FUERA
-- del repo. NOTA: Mason baja binarios de internet; algunos necesitan node (ya lo
-- tenés). En Windows detrás de proxy corporativo puede fallar alguno (ver CLAUDE.md).
--
-- ATAJOS: nvim 0.12 ya trae los principales DE FÁBRICA, así que acá se mapea lo
-- mínimo que falta. Los nativos (existen siempre, no hay que configurarlos):
--   grn  renombrar símbolo      gra  acciones de código (quick fix)
--   grr  ver referencias        gri  ir a la implementación
--   grt  ir al tipo             grx  ejecutar codelens
--   gO   estructura del archivo (símbolos)   K  hover (documentación)
--   <C-w>d  ver el diagnóstico bajo el cursor
--   <C-s>   (en modo insert) ver los parámetros de la función
--
-- Antes este archivo mapeaba gr, gI, <leader>rn, <leader>ca y <leader>d, que son
-- exactamente esos defaults duplicados. Peor todavía: mapear `gr` A SECAS convierte
-- `gr` en prefijo AMBIGUO, así que nvim tiene que esperar los 400 ms de timeoutlen
-- para saber si venía grn/gra/grr — metía lag perceptible en los seis nativos.
--
-- Lo que sí se mapea acá (no tiene default):
--   gd       ir a la definición ('gd' nativo es la declaración LOCAL, no el LSP)
--   [d / ]d  saltar al diagnóstico anterior / siguiente
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
    -- NO hace falta pasar `capabilities` a mano. Antes acá había un
    -- require('blink.cmp').get_lsp_capabilities(), y era redundante: desde nvim
    -- 0.11 blink registra sus capabilities solo, en su plugin/, con
    -- vim.lsp.config('*', {...}) — o sea que aplican a TODOS los servidores.
    -- Encima ese require forzaba a lazy.nvim a cargar blink acá, saltándose su
    -- propio evento declarado. Lo dice su doc: "with 0.11+ you may skip this step".
    -- ---------------------------------------------------------------------
    -- Servidores del stack decidido (Web, Python, Bash, Lua). La clave es el
    -- nombre del servidor; el valor, su config (settings específicos).
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
