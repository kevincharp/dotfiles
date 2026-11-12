-- ============================================================================
-- tipos-archivo.lua — detección de tipo de archivo propia (vim.filetype.add)
-- ============================================================================
-- Se carga antes que los plugins: registrado tarde, el primer archivo ya se detectó sin
-- estas reglas.
-- ============================================================================

vim.filetype.add({
  filename = {
    ['docker-compose.yml'] = 'yaml.docker-compose',
    ['docker-compose.yaml'] = 'yaml.docker-compose',
    ['compose.yml'] = 'yaml.docker-compose',
    ['compose.yaml'] = 'yaml.docker-compose',
  },
  pattern = {
    -- Variantes por entorno: compose.prod.yml, Dockerfile.dev.
    ['docker%-compose%..*%.ya?ml'] = 'yaml.docker-compose',
    ['compose%..*%.ya?ml'] = 'yaml.docker-compose',
    ['Dockerfile%..*'] = 'dockerfile',
    ['.*%.[Dd]ockerfile'] = 'dockerfile',
  },
})

-- Filetype compuesto: el compose recibe yamlls (esquema) y además
-- docker_compose_language_service.
