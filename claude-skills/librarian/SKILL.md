---
name: librarian
description: Recomienda skills, plugins y repositorios guardados (estrellas de GitHub) para el proyecto o la tarea actual, evalúa cada candidato en el momento y los instala en el proyecto solo tras confirmación. Usar al arrancar un proyecto nuevo, cuando el usuario pregunta qué herramienta tiene para algo ("qué tengo para diseño", "necesito algo para deploy", "hay alguna skill para…") o invoca /librarian.
argument-hint: "[qué necesitás; vacío = analizar el proyecto actual]"
---

# Librarian

La base global de plugins es mínima a propósito. Todo lo demás vive en la
biblioteca del usuario (sus repos con estrella en GitHub y los marketplaces
registrados) y se instala **por proyecto**. Tu trabajo es buscar ahí qué le
sirve a este proyecto, evaluar los candidatos con lo que leas en el momento,
mostrarlos en un formato fijo e instalar solo lo que el usuario elija.

## 1. Entender qué se necesita

- Con argumento: esa es la necesidad.
- Sin argumento: deducirla del proyecto. Leer `AGENTS.md`, `README.md` y los
  manifiestos que existan (`package.json`, `Cargo.toml`, `pyproject.toml`,
  `wrangler.toml`…), más lo que el usuario ya contó en la conversación.
- Si no alcanza para saber de qué va el proyecto, hacer **una** pregunta y
  esperar la respuesta.

Resumir la necesidad en una línea y sacar de ella de 4 a 8 palabras clave
(en inglés y en español): 2 a 4 de la **tarea** y 2 a 4 del **stack** del
proyecto (lenguajes, frameworks, plataforma). Van juntas en un solo `grep -iE`.

## 2. Consultar las fuentes

Solo se recomienda lo que aparece en estas fuentes, en este orden. No recomendar
de memoria.

| Fuente | Qué da | Cómo |
|---|---|---|
| Instalado | Qué hay activo, en **todos** los alcances (usuario y proyecto) | `claude plugin list` |
| Marketplaces | Qué se instala con un comando | `~/.claude/plugins/marketplaces/*/.claude-plugin/marketplace.json` |
| Estrellas de GitHub | **Todos** los repos guardados, con su lista | consulta de abajo |
| Catálogo abierto (skills.sh) | Solo si lo anterior no tiene nada que sirva | `npx skills find <consulta>` |

Las estrellas se leen **en vivo** (cambian seguido) y completas, no por lista.
Esto arma un archivo con un repo por línea; después se filtra con `grep`, sin
leerlo entero:

```bash
T=$(mktemp -d)
gh api graphql --paginate -f query='query($endCursor:String){viewer{starredRepositories(first:100,after:$endCursor){pageInfo{hasNextPage endCursor} nodes{nameWithOwner description pushedAt isArchived primaryLanguage{name} repositoryTopics(first:5){nodes{topic{name}}}}}}}' \
  --jq '.data.viewer.starredRepositories.nodes[]|[.nameWithOwner,(.primaryLanguage.name//"-"),.pushedAt[:10],(if .isArchived then "archivado" else "-" end),([.repositoryTopics.nodes[].topic.name]|join(",")),((.description//"-")|gsub("[\\t\\n\\r]";" ")|.[:140])]|@tsv' \
  | LC_ALL=C sort > "$T/stars.tsv"
gh api graphql -f query='{viewer{lists(first:50){nodes{name items(first:100){totalCount nodes{... on Repository{nameWithOwner}}}}}}}' \
  --jq '.data.viewer.lists.nodes[]|.name as $l|.items.nodes[]|[.nameWithOwner,$l]|@tsv' > "$T/lists.tsv"
awk -F'\t' '{a[$1]=a[$1] (a[$1]?"; ":"") $2} END{for(k in a) print k"\t"a[k]}' "$T/lists.tsv" | LC_ALL=C sort > "$T/by-repo.tsv"
LC_ALL=C join -t$'\t' -a1 "$T/stars.tsv" "$T/by-repo.tsv" | awk -F'\t' 'NF<7 || $7 !~ /Descartados/' > "$T/library.tsv"
grep -iE '<palabra1>|<palabra2>|<palabra3>' "$T/library.tsv"
```

Columnas de `library.tsv`: repo, lenguaje, último cambio, archivado, temas,
descripción, listas. Una lista con más de 100 repos se corta en la consulta de
listas: si su `totalCount` lo supera, pedir esa lista aparte con `after:`.
Si `gh` no está autenticado, decirlo y seguir con las otras fuentes.

Lo que está en la lista **Descartados** ya fue rechazado por el usuario: no se
recomienda (el `awk` de arriba lo saca).

## 3. Filtrar y evaluar

- Sacar lo que ya está activo en este proyecto (mencionarlo en una línea, con
  todos los plugins activos de `claude plugin list`, no solo los que parecen
  relevantes; alcances user, project y local). Si algo instalado ya cubre lo
  mismo que un candidato, el candidato no va en ninguna tabla: se nombra solo en
  "Ya activo acá", con una frase de qué cubre.
- Quedarse con **3 a 5 finalistas** por tabla; si dos hacen lo mismo,
  recomendar una y nombrar la otra como alternativa. Si no hay nada que sirva,
  escribir "Nada en la biblioteca para esto" en vez de rellenar.
- Marcar un repo **archivado** o **sin cambios hace más de un año**.
- Leer el README de cada finalista (`gh repo view <owner/repo>`) y evaluar en
  ese momento, con lo que está instalado ahora:
  - **Invasividad:** hooks, servidores MCP, auto-update, descargas de binarios,
    control de un navegador, ejecución de código con credenciales.
  - **Costo:** plan de pago, claves de API, uso de tokens alto.
  - **Solapamiento** con lo instalado y con los marketplaces.
  - **Licencia** de cada repo (`gh repo view <repo> --json licenseInfo,stargazerCount`):
    siempre se informa en la tabla de repos; si `licenseInfo` viene vacío,
    escribir "sin licencia". Esta regla de licencias es la única: el resto del
    documento remite a ella.
    - **Copyleft** (GPL, AGPL), **sin licencia** u **otra** no estándar:
      leer como referencia de ideas, **no copiar código**, salvo que el
      proyecto del usuario use esa misma licencia.
    - **Permisiva** (MIT, Apache, BSD): se puede reutilizar con la atribución
      que pida la licencia.
- Para lo que viene de skills.sh, verificar antes de recomendar: fuente oficial
  o conocida, más de 1.000 instalaciones, repo con más de 100 estrellas. Con
  menos, avisarlo como riesgo. Trae código sin revisar.

## 4. Responder con este formato

```markdown
**Necesidad:** <una línea>
**Ya activo acá:** <plugins activos que cubren parte, con qué cubren, o "nada específico">

### Plugins y skills instalables
| Plugin | Qué aporta a este proyecto | Skills que trae | Fuente | Recomendación |
|---|---|---|---|---|

### Repositorios guardados
| Repo | Qué es | Por qué podría servir | Licencia y riesgos (invasividad, costo, solapamiento) | Lista | Último cambio |
|---|---|---|---|---|---|

**Mi sugerencia:** <qué instalaría y qué repo miraría, en una o dos líneas>

Respondé, por ejemplo: "instalá X e Y, y analicemos el repo Z".
```

- **Fuente** dice de dónde salió la fila (`marketplace <nombre>`, `estrellas`,
  `skills.sh`). Una fila sin fuente no va.
- **Recomendación**: `sí`, `opcional` o `alternativa a <otro>`. Esta última vale
  solo frente a otro candidato de la misma tabla, nunca frente a algo ya
  instalado.
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

**Analizar un repo**: leer su README y resumir qué es, cómo se usaría acá, qué
pide instalar y qué riesgo tiene. No clonar ni ejecutar nada sin que el usuario
lo pida. Si el usuario quiere instalarlo como plugin y el repo no publica
`marketplace.json`, explicar que hay que sumarlo a
`~/.dotfiles/.claude-plugin/marketplace.json` (commit y push antes de
instalar).

**Usar un repo como referencia**: el usuario guarda repos también para
aprender de ellos (ver cómo resolvieron un problema, o hacer algo mejor). Si
pide analizarlos, hacerlo de **solo lectura** (leer el README y el código con
`gh repo view <repo>` y `gh api repos/<owner>/<repo>/contents/<ruta>`; no
clonar ni ejecutar nada), contra las decisiones del proyecto: las que están en
`AGENTS.md`, `README.md` y `STATUS.local.md`, y lo que el usuario cuente en la
conversación. Los tickets de GitHub solo se leen si el usuario lo pide. Con
varios repos, se pueden analizar en paralelo con subagentes.
Devolver, en este orden:
1. Cómo resuelve cada repo lo que le importa al proyecto, y qué hace distinto.
2. Qué vale la pena **adoptar** (la idea; el código solo si la regla de licencias
   del paso 3 lo permite).
3. Qué **no copiar**, por seguridad o calidad (por ejemplo historial sin cifrar,
   peticiones de red inesperadas, ejecución de comandos, ausencia de tests).
4. Qué dice el repo que el proyecto ya hace mejor.
Marcar cada afirmación que no se pudo comprobar leyendo el código.

**Descartar un repo**: si el usuario decide que un repo no le sirve, ofrecer
sumarlo a su lista **Descartados** de GitHub. Es una escritura hacia afuera:
pedir confirmación primero, y no descartar nada por iniciativa propia. Se suma
sin sacarlo de sus otras listas. Si la lista no existe, decirlo y no crearla.

```bash
# ids del repo y de sus listas actuales, más el de Descartados
gh api graphql -f query='{ viewer { lists(first: 50) { nodes { id name items(first: 100) { totalCount nodes { ... on Repository { id nameWithOwner } } } } } } }' \
  --jq '.data.viewer.lists.nodes[] | .id as $l | .name as $n | .items.nodes[] | "\($l)\t\($n)\t\(.id)\t\(.nameWithOwner)"'
# una vez por lista, con la sintaxis lists[]= (un array se arma repitiendo la clave)
gh api graphql -f query='mutation($item:ID!,$lists:[ID!]!){updateUserListsForItem(input:{itemId:$item,listIds:$lists}){clientMutationId}}' \
  -f item=<id repo> -f 'lists[]=<id lista 1>' -f 'lists[]=<id lista 2>' -f 'lists[]=<id Descartados>'
```

`listIds` reemplaza el conjunto completo: incluir **todas** las listas que ya
tenía, más Descartados. Si alguna lista leída tiene `totalCount` mayor a 100, el
repo podría estar en ella sin aparecer: pedir esa lista paginada antes de
escribir, porque la mutation le sacaría la lista que falte. Verificar después
leyendo las listas del repo.

## Lo que no hace

- No instala nada global ni desinstala nada.
- No edita archivos del repo del usuario ni la documentación de los dotfiles.
- No publica nada en GitHub (comentarios en tickets, issues nuevos, listas) sin
  que el usuario lo pida; lo que concluya lo propone y espera el OK. La única
  escritura que prevé es sumar un repo a **Descartados**, y solo con su
  confirmación explícita.
- No certifica que el código de un repo sea seguro. En la recomendación solo lee
  descripción y README; en el modo referencia lee código y señala riesgos
  visibles, como observaciones sin garantía.
