---
name: bibliotecario
description: Recomienda skills, plugins y repositorios guardados para el proyecto o la tarea actual, y los instala en el proyecto solo tras confirmación. Usar al arrancar un proyecto nuevo, cuando el usuario pregunta qué herramienta tiene para algo ("qué tengo para diseño", "necesito algo para deploy", "hay alguna skill para…") o invoca /bibliotecario.
argument-hint: "[qué necesitás; vacío = analizar el proyecto actual]"
---

# Bibliotecario

La base global de plugins es mínima a propósito. Todo lo demás vive en una
biblioteca (marketplaces registrados + repos con estrella en GitHub) y se
instala **por proyecto**. Tu trabajo es buscar ahí qué le sirve a este proyecto,
mostrarlo en un formato fijo e instalar solo lo que el usuario elija.

## 1. Entender qué se necesita

- Con argumento: esa es la necesidad.
- Sin argumento: deducirla del proyecto. Leer `AGENTS.md`, `README.md` y los
  manifiestos que existan (`package.json`, `Cargo.toml`, `pyproject.toml`,
  `wrangler.toml`…), más lo que el usuario ya contó en la conversación.
- Si no alcanza para saber de qué va el proyecto, hacer **una** pregunta y
  esperar la respuesta.

Resumir la necesidad en una línea antes de buscar.

## 2. Consultar las fuentes

Solo se recomienda lo que aparece en estas fuentes. No recomendar de memoria.

| Fuente | Qué da | Cómo |
|---|---|---|
| Instalado | Qué hay activo y en qué alcance | `claude plugin list` |
| Marketplaces | Qué se puede instalar con un comando | `~/.claude/plugins/marketplaces/*/.claude-plugin/marketplace.json` |
| Evaluaciones del usuario | Qué descartó, pausó o ya eligió, y por qué | `~/.dotfiles/docs/skills-radar.md` y `~/.dotfiles/docs/agent-skills-catalogo.md` |
| Estrellas de GitHub | Repos guardados, por lista | consulta de abajo |

Listas de estrellas (primero los nombres, después solo las que tocan el tema):

```bash
gh api graphql -f query='{ viewer { lists(first: 50) { nodes { name items { totalCount } } } } }' \
  --jq '.data.viewer.lists.nodes[] | "\(.items.totalCount)\t\(.name)"'

gh api graphql -f query='{ viewer { lists(first: 50) { nodes { name items(first: 100) { nodes { ... on Repository { nameWithOwner description pushedAt } } } } } } }' \
  --jq '.data.viewer.lists.nodes[] | select(.name | test("<lista 1>|<lista 2>")) | .name as $l | .items.nodes[] | "\($l)\t\(.nameWithOwner)\t\(.pushedAt[:10])\t\(.description // "-")"'
```

Elegir como mucho 4 listas por consulta. Si `gh` no está autenticado, decirlo y
seguir con las otras fuentes.

## 3. Filtrar

- Sacar lo que ya está activo en este proyecto (mencionarlo en una línea).
- Sacar lo que `skills-radar.md` marca como descartado. Si algo está pausado o
  tuvo mala experiencia, puede aparecer, con esa nota.
- Si dos opciones hacen lo mismo, recomendar una y nombrar la otra como
  alternativa. Menos es más: como mucho 5 filas por tabla.
- Si no hay nada que sirva en una tabla, escribir "Nada en la biblioteca para
  esto" en vez de rellenar.

## 4. Responder con este formato

```markdown
**Necesidad:** <una línea>
**Ya activo acá:** <plugins que cubren parte, o "nada específico">

### Plugins y skills instalables
| Plugin | Qué aporta a este proyecto | Skills que trae | Fuente | Recomendación |
|---|---|---|---|---|

### Repositorios guardados
| Repo | Qué es | Por qué podría servir | Lista | Último cambio |
|---|---|---|---|---|

**Mi sugerencia:** <qué instalaría y qué repo miraría, en una o dos líneas>

Respondé, por ejemplo: "instalá X e Y, y analicemos el repo Z".
```

- **Fuente** dice de dónde salió la fila (`marketplace <nombre>`, `radar`).
  Una fila sin fuente no va.
- **Recomendación**: `sí`, `opcional` o `alternativa a <otro>`.
- Un repo con estrella que no está en ningún marketplace va en la segunda
  tabla: no se instala con un comando.

## 5. Actuar solo sobre lo que el usuario eligió

**Instalar un plugin** (nunca antes de la confirmación, nunca en alcance user):

```bash
claude plugin install <plugin>@<marketplace> --scope local
```

- `--scope local` por defecto: queda en `.claude/settings.local.json`, fuera
  del repo. Usar `--scope project` solo si el usuario lo pide.
- Antes de instalar, avisar si el plugin trae hooks o servidores MCP: corren
  código en la máquina.
- Después, pedirle al usuario que corra `/reload-plugins` y confirmar con
  `claude plugin list` que quedó en este proyecto.

**Analizar un repo**: leer su README (`gh repo view <owner/repo>`) y resumir
qué es, cómo se usaría acá, qué pide instalar y qué riesgo tiene. No clonar ni
ejecutar nada sin que el usuario lo pida. Si el usuario quiere instalarlo como
plugin y el repo no publica `marketplace.json`, explicar que hay que sumarlo a
`~/.dotfiles/.claude-plugin/marketplace.json` (commit y push antes de instalar).

## Lo que no hace

- No instala nada global ni desinstala nada.
- No edita `skills-radar.md` por su cuenta; si el usuario descarta o adopta
  algo, ofrecer anotarlo.
- No juzga si el código de un repo es seguro: solo lee su descripción y README.
