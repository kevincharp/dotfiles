# Referencia de comandos

Todo lo que agregan los shells del repo (`bashrc` / `zshrc` / `profile.ps1`),
agrupado por categoría. En la terminal tenés esta misma ayuda con **`dothelp`**
(menú interactivo con fzf) o `dothelp <filtro>` (listado estático).

Convención de las plantillas: `<arg>` = requerido · `[arg]` = opcional.

**Disponibilidad:** salvo que se indique lo contrario, los comandos existen en
los tres shells (bash, zsh y PowerShell). Los marcados *(Linux)* viven solo en
bash/zsh; los *(Windows)* solo en PowerShell.

---

## Git — flujo diario

| Comando | Qué hace |
|---|---|
| `gs` / `gst` | `git status` / `git status -sb` |
| `ga` / `gc` / `gcm "msg"` / `gcmm "msg"` | add / commit / commit -m |
| `gca` / `gcam "msg"` | amend / amend con mensaje nuevo |
| `gl` / `glo` / `glg` | log gráfico corto (15) / medio (30) / completo con todas las ramas |
| `gpl` / `gp` / `gpf` / `gpo` | pull / push / push --force-with-lease / push origin |
| `gco` / `gcb` / `gnew` | checkout / checkout -b (ambos alias del mismo gesto) |
| `gb` / `gbd` / `gbr` / `gbra` | branch / branch -d / branch -vv / branch -a -vv |
| `gsta` / `gstp` | stash / stash pop |
| `grh` / `grs` | reset HEAD / reset --soft |
| `grls` | remote -v |

## Git — helpers con lógica

| Comando | Qué hace |
|---|---|
| `gsw <rama>` | Switch inteligente: usa la rama local, trackea la remota, o la crea si no existe |
| `gsync` | `fetch --all --prune` + `pull --rebase --autostash` |
| `gup` / `gpsu` | Set upstream de la rama actual / push inicial con tracking |
| `gfixup [commit]` | `commit --fixup` (HEAD por defecto) |
| `gundo` | Deshace el último commit conservando los cambios |
| `gclean` | Borra archivos sin trackear (muestra preview y pide confirmación) |
| `gprune` | Borra ramas locales ya mergeadas |
| `gcleanbranches` | Borra ramas cuyo upstream remoto ya no existe (`[gone]`) |
| `gcoi` *(Linux)* | Checkout interactivo de ramas con fzf |
| `gwork [dir]` *(Linux)* | `cd` al directorio de trabajo (`$work` por defecto) |
| `gbrowser <alias>:<grupo>` *(Windows)* | Lista los repos de un namespace GitLab/GitHub vía API |

## Git — identidades por perfil

Requieren el [vault](adaptalo.md#el-vault) (ahí viven los nombres/emails).

| Comando | Qué hace |
|---|---|
| `gclone -p <perfil> -u <url> [-d dir]` | Clona y aplica la identidad del perfil (nombre, email, autocrlf, rebase) |
| `gset-profile <perfil>` | Aplica un perfil a un repo ya existente |
| `ginit <perfil> [path]` | `git init` + perfil + `.gitignore` base (plantilla `git/gitignore-proyecto`) |
| `gremote <alias-ssh> <ns/repo> [nombre]` | Agrega/actualiza un remote usando un host alias SSH |

## SSH y vault

| Comando | Qué hace |
|---|---|
| `ssh-newkey <nombre>` | Genera un par ed25519, lo cifra con age y lo deja listo en el vault (con alta opcional en `ssh/config`) |
| `vault-sync` | Pull del vault + aplica `ssh/config` + desencripta las claves que falten |

## Sistema / procesos

| Comando | Qué hace |
|---|---|
| `port <puerto>` | Muestra qué proceso escucha en ese puerto |
| `killport <puerto>` | Mata el proceso que escucha en ese puerto |
| `killdev` | Mata lo que escuche en puertos comunes de dev (3000, 4200, 5173, 8080…) |
| `update-all` | Actualiza lo que el gestor de paquetes no cubre (Linux: dnf+flatpak+npm+openlogi · Windows: winget+npm) |
| `battery-limit [status\|on\|off]` *(Linux)* | Tope de carga ~80 % en Lenovo (conservation mode) |

## Navegación / archivos

| Comando | Qué hace |
|---|---|
| `y` | yazi con *cd-on-exit*: al salir quedás en el último directorio navegado |
| `open [ruta]` | Abre archivo/carpeta con la app por defecto del sistema |
| `edit <archivo>` | Abre en VSCode si está; si no, nvim (Windows: Notepad) |
| `z <patrón>` | zoxide: salta al directorio más usado que matchee |
| `ll` / `la` / `ls` | Listados con eza (íconos, dirs primero) o fallback nativo |
| `vi` / `vim` / `nano` | Todos apuntan a nvim |
| `mkdirp` | `mkdir -p` |

**Solo Windows** (emulan comandos que en Linux son nativos): `cat`, `grep`,
`find`, `head`, `tail`, `tailf`, `which`, `less`, `touch`, `rmrf`, `lss`,
`export`, `unset`, `echolf`, `cd -`, `open-here`.

## Historial

| Comando | Qué hace |
|---|---|
| `↑` (flecha arriba) | Lista vertical del historial en fzf, filtrada por **prefijo** con lo ya tipeado (estilo PSReadLine ListView) |
| `Ctrl+R` | Búsqueda difusa por cualquier parte del comando |
| `clear-history [patrón]` | Sin argumentos vacía todo el historial (confirma antes); con patrón borra solo las líneas que matcheen (ideal para sacar un token pegado por error) |
| `edit-history` | Abre el archivo de historial en el editor |

## Nube (iCloud vía rclone) *(Linux)*

Requieren configurar el remote una vez con `rclone config` (pide Apple ID + 2FA).

| Comando | Qué hace |
|---|---|
| `icloud-mount` / `icloud-umount` | Monta/desmonta iCloud Drive en `~/icloud` |
| `icloud-ls [carpeta]` | Lista sin descargar |
| `icloud-pull <origen> <destino>` | Descarga incremental en paralelo |
| `icloud-move <origen> <destino>` | Como pull pero **borra de iCloud** lo copiado (dry-run + confirmación antes) |

## Dotfiles / configuración *(Linux)*

| Comando | Qué hace |
|---|---|
| `dothelp [filtro]` | Esta misma ayuda, en la terminal |
| `bash ~/.dotfiles/git-profiles.sh` | Asistente de perfiles git + vault propio (ver [adaptalo](adaptalo.md#el-vault)) — en Windows: `pwsh -File ~/.dotfiles/git-profiles.ps1` |
| `ptyxis-save` / `ptyxis-load` | Vuelca al repo / restaura la config de la terminal Ptyxis (dconf) |
| `gnome-save` / `gnome-load` | Ídem para GNOME (atajos, dock, extensiones) — ver [arquitectura](arquitectura.md#dconf) |

## Herramientas

| Comando | Qué hace |
|---|---|
| `claude-smg` | Lanza Claude Code contra AWS Bedrock con perfil SSO (renueva el login si expiró). Opcional — ver [adaptación](adaptalo.md#aws--bedrock-opcional) |
