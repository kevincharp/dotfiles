# Adaptá el repo a tu cuenta

Este repo nació personal: hay un nombre de usuario de GitHub cableado, perfiles
de identidad git con nombres propios y un repo privado («vault») al que solo yo
tengo acceso. **Nada de eso te impide usarlo** — esta guía explica los tres
niveles de adopción, del más liviano al más completo.

---

## Nivel 0 — Probarlo sin tocar nada

Podés correr el instalador tal cual y elegir **«Saltar»** (la opción por
defecto) cuando pregunte por el vault. Obtenés todo lo público:

- El catálogo completo de herramientas (elegís qué instalar).
- Shells configurados (bash/zsh/PowerShell) con prompt, colores, historial
  estilo PSReadLine, funciones y aliases — ver la [referencia](comandos.md).
- Configs de Neovim, terminal, yazi, lazygit, editorconfig.
- En Fedora/GNOME: atajos, dock y extensiones (con *mis* preferencias — ver
  [abajo](#gnome-los-dconf-traen-mis-preferencias)).

Lo que **no** vas a tener sin vault (el bootstrap lo avisa como WARN y sigue):

- `~/.gitconfig` e identidades por perfil (`gclone`, `gset-profile`, `ginit`).
- `~/.ssh/config` y claves SSH.
- El remote de iCloud para rclone.

Tu git y tu SSH quedan como estaban: configuralos a mano como siempre.

> Para desinstalar y volver al estado previo: `bash ~/.dotfiles/uninstall.sh`
> (restaura los backups automáticos). Ver [instalación](instalacion.md#desinstalación).

---

## Nivel 1 — Fork con tu usuario

Para que el one-liner instale **tu** fork y busque **tu** vault:

1. **Forkeá** el repo (y creá tu vault si querés — nivel 2).
2. Cambiá la constante `GH_USER` al principio de **`install.sh`** y
   **`install.ps1`** por tu usuario de GitHub. De ahí derivan las URLs del repo
   público y del vault.
3. Revisá lo que es genuinamente personal y borrá/ajustá lo que no te sirva:

   | Qué | Dónde | Nota |
   |---|---|---|
   | Perfiles y carpetas de contexto | Los define **tu vault** (`git-identities` + `GIT_CONTEXT_DIRS`) — el [asistente](#el-vault) lo hace solo | Sin vault, el bootstrap cae a las carpetas históricas del autor |
   | Config del mouse Logitech MX | `openlogi/` + entrada `openlogi` del catálogo | Solo tiene sentido con ese hardware |
   | Dumps de GNOME | `gnome/*.dconf` | Ver la sección de GNOME abajo |
   | Tope de batería Lenovo | `battery-limit` en bashrc/zshrc | Solo hace algo en Lenovo (ideapad/ThinkBook) |
   | AWS / Bedrock | — | Opcional de fábrica: respondé «no» y no existe |

4. Instalá con tu URL:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/<TU-USUARIO>/dotfiles/main/install.sh | bash
   ```

---

## Nivel 2 — Tu propio vault

<a name="el-vault"></a>
El **vault** es un segundo repo, **privado**, con todo lo que no puede ser
público: claves SSH (cifradas), identidades git con emails, tokens de servicios.
El bootstrap combina ambos: aplica lo público y desencripta lo del vault.
Así el repo principal puede compartirse sin exponer nada.

### El camino fácil: el asistente

No hace falta armar nada a mano — corré:

```bash
bash ~/.dotfiles/git-profiles.sh        # Windows: pwsh -File ~/.dotfiles/git-profiles.ps1
```

(o elegí **«No tengo vault — crear mis perfiles de git ahora»** cuando el
instalador pregunte). Es un asistente por consola: te pide tus contextos
(perfil, nombre, email, plataforma, usuario) y **genera y aplica** todo lo que
describe esta sección — el `.gitconfig` con identidad automática, los perfiles,
las identidades para los shells, claves SSH con su alias (opcionales), las
carpetas de contexto — y al final ofrece crear el repo privado en GitHub vía
`gh`. Lo que sigue explica **qué** genera, por si querés armarlo o ajustarlo a
mano.

### La estructura, por dentro

Un repo privado llamado **`dotfiles-vault`** con esta forma:

```
dotfiles-vault/
├── git/
│   ├── config               # ~/.gitconfig: useConfigOnly + includeIf por remoto
│   ├── config-personal      # identidad de cada perfil (user.name / user.email)
│   └── config-<perfil>...
├── shell/
│   ├── git-identities.sh    # identidades para bash/zsh (formato abajo)
│   └── git-identities.ps1   # ídem PowerShell
├── ssh/
│   ├── config               # tus Host con IdentityFile + IdentitiesOnly
│   └── keys/
│       ├── <clave>.age      # privadas cifradas con age (passphrase)
│       └── <clave>.pub      # públicas en claro
└── rclone/
    └── rclone.conf          # (opcional) remote de iCloud u otra nube
```

### Identidades git — el formato esperado

`shell/git-identities.sh` (bash/zsh y `test-bootstrap.sh` lo sourcean):

```bash
# Perfil → nombre y email
GIT_IDENTITIES_NAME[personal]="Tu Nombre"
GIT_IDENTITIES_EMAIL[personal]="vos@mail.com"
GIT_IDENTITIES_NAME[work]="Tu Nombre"
GIT_IDENTITIES_EMAIL[work]="vos@empresa.com"

# Host alias SSH → nombre de la clave en ~/.ssh
GIT_SSH_ALIASES[github.com-tuuser]="tuuser-github"
GIT_SSH_ALIASES[gitlab.com-empresa]="empresa-gitlab"

# Para el test de resolución de identidad: "url|perfil|etiqueta"
GIT_PROFILE_REMOTES=(
    "git@github.com-tuuser:tuuser/un-repo.git|personal|GitHub personal"
)

# (Opcionales) Carpetas de contexto que crea/verifica el bootstrap bajo
# ~/repositorios/, y mapa archivo→perfil (~/.gitconfig-<sufijo> pertenece a
# <perfil>) para los tests. Sin definirlos, se usan los valores históricos.
GIT_CONTEXT_DIRS=(personal trabajo)
GIT_IDENTITY_FILES[personal]="personal"
GIT_IDENTITY_FILES[trabajo]="work"
```

`shell/git-identities.ps1` (PowerShell):

```powershell
$GitIdentities = @{
    personal = @{ name = 'Tu Nombre'; email = 'vos@mail.com' }
    work     = @{ name = 'Tu Nombre'; email = 'vos@empresa.com' }
}
# Para gbrowser (listar repos por API): alias → plataforma/base/token
$GitHostAliases = @{
    'github.com-tuuser' = @{ platform='github'; base='https://api.github.com'; tokenEnv='GITHUB_TOKEN_TUUSER' }
}
# Espejo de las listas del .sh (mismos datos): $GitSshAliases,
# $GitProfileRemotes, $GitContextDirs y $GitIdentityFiles.
```

### Cómo funciona la identidad automática

El `git/config` del vault usa `includeIf` con `hasconfig:remote.*.url` (git ≥
2.36): según la URL del remoto, git carga el `config-<perfil>` correspondiente.
Con `user.useConfigOnly=true`, un repo sin perfil aplicable **no comitea** con
una identidad equivocada — falla y te avisa. `gclone -p <perfil> -u <url>`
aplica todo al clonar.

### Claves SSH: alta y sincronización

No manipulás archivos `.age` a mano — hay dos comandos:

- **`ssh-newkey <nombre>`** — genera el par ed25519, cifra la privada con age
  (te pide una passphrase; usá la misma para todas), copia la pública al vault,
  te ofrece dar de alta el `Host` en `ssh/config` y deja el `git add` hecho.
- **`vault-sync`** — en cualquier otra máquina: pull del vault, aplica
  `ssh/config` y desencripta solo las claves que falten.

---

## GNOME: los dconf traen *mis* preferencias

`gnome/*.dconf` son volcados de **mi** configuración (atajos como
`Super+Shift+S` para Flameshot, dock, extensiones). En Fedora/GNOME el
bootstrap los aplica tal cual. Si preferís los tuyos:

1. Configurá GNOME a tu gusto por la GUI.
2. Corré `gnome-save` (y `ptyxis-save` para la terminal) — vuelca **tu** estado
   al repo, listo para commitear.

O directamente borrá los `.dconf` que no quieras aplicar (el bootstrap saltea
los que no existen).

## Reglas para agentes de IA

`.claude/CLAUDE.md` es la **fuente única de reglas** para los agentes de IA:
Claude Code lo lee directo y el bootstrap lo symlinkea además como `AGENTS.md`
para Codex (`~/.codex/`) y opencode (`~/.config/opencode/`), si están
instalados. Un solo archivo, tres CLIs.

El archivo tiene dos mitades:

- **Base funcional** (commits convencionales, git, proyectos nuevos, secretos,
  verificación): está formulada contra los mecanismos del repo — `ginit`,
  perfiles del vault, plantilla de gitignore — así que **sirve tal cual** con
  tu propio vault y tus propios perfiles.
- **Preferencias** (idioma de respuestas, comentarios y commits): personal —
  editá esa sección a tu gusto.

Relacionado: `ginit <perfil>` inicializa proyectos con la identidad correcta
**y** un `.gitignore` base desde la plantilla `git/gitignore-proyecto`
(personalizable — es un archivo más del repo).

## AWS / Bedrock (opcional)

Todo el bloque de AWS SSO existe para `claude-smg` (Claude Code facturado vía
AWS Bedrock, típico en empresas). Si no es tu caso, respondé **no** cuando el
instalador pregunte y el tema desaparece. Si sí lo es:
[instalación → AWS SSO](instalacion.md#aws-sso--bedrock-opcional).
