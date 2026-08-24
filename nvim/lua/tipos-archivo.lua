-- ============================================================================
-- tipos-archivo.lua — detección de tipo de archivo propia (vim.filetype.add)
-- ============================================================================
-- nvim reconoce solo la enorme mayoría de los archivos. Acá van las excepciones
-- que necesita este stack, porque de qué tipo es un archivo depende TODO lo demás:
-- qué servidor LSP arranca, qué parser de treesitter resalta y qué formateador
-- corre al guardar.
--
-- Se carga desde init.lua, antes de los plugins: si se registra tarde, el primer
-- archivo que abrís ya se detectó con las reglas viejas.
-- ============================================================================

vim.filetype.add({
  filename = {
    -- Los compose sueltos, con el nombre exacto que usa Docker.
    ['docker-compose.yml'] = 'yaml.docker-compose',
    ['docker-compose.yaml'] = 'yaml.docker-compose',
    ['compose.yml'] = 'yaml.docker-compose',
    ['compose.yaml'] = 'yaml.docker-compose',
  },
  pattern = {
    -- Y las variantes por entorno: compose.prod.yml, docker-compose.override.yaml…
    ['docker%-compose%..*%.ya?ml'] = 'yaml.docker-compose',
    ['compose%..*%.ya?ml'] = 'yaml.docker-compose',
    -- Dockerfile con sufijo: Dockerfile.dev, Dockerfile.prod.
    ['Dockerfile%..*'] = 'dockerfile',
    ['.*%.[Dd]ockerfile'] = 'dockerfile',
  },
})

-- Por qué 'yaml.docker-compose' con PUNTO y no 'yaml' a secas: es un filetype
-- compuesto (dot-separated), y nvim lo trata como los dos a la vez. Así un
-- compose recibe LOS DOS servidores: yamlls (que le pone el esquema de compose de
-- SchemaStore y valida la estructura entera) y docker_compose_language_service
-- (que además sabe de servicios, redes y volúmenes). Con 'yaml' pelado se perdía
-- el segundo; con 'docker-compose' pelado se perdían el esquema, el resaltado de
-- treesitter y el formateo con prettier.
