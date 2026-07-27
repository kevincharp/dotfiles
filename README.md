# dotfiles

**Un entorno de desarrollo completo y reproducible, con un solo comando.**
Linux (Fedora/Debian/Arch) y Windows, con paridad real entre ambos: mismo
prompt, mismos atajos, mismas funciones en bash, zsh y PowerShell.

![Captura del entorno](screenshots/2026-07-09_22-31.png)

## Qué incluye

- **Instalador interactivo con selector**: elegís qué instalar de un catálogo de
  ~30 herramientas por grupos (core, shell, dev, cloud, fonts, apps). Nada se
  instala sin que lo marques.
- **Tres shells, una experiencia**: prompt [oh-my-posh](https://ohmyposh.dev)
  temado, syntax highlighting mientras tipeás, sugerencias desde el historial y
  la misma paleta de colores en bash, zsh y PowerShell 7.
- **Historial estilo PSReadLine en Linux**: `↑` abre la lista del historial
  filtrada por prefijo (fzf); `Ctrl+R` busca difuso. En los tres shells.
- **[~60 comandos y aliases](docs/comandos.md)** de git, puertos, navegación y
  sistema — con `dothelp` como ayuda interactiva integrada.
- **Secretos fuera del repo**: las claves SSH viven cifradas con
  [age](https://age-encryption.org) en un segundo repo privado («vault»), y las
  identidades de git se aplican solas según el remoto (`includeIf` +
  `hasconfig`). Este repo puede ser público porque no contiene nada sensible —
  y si no tenés vault, **un asistente te crea el tuyo** en la primera instalación.
- **Escritorio versionado (Fedora/GNOME)**: atajos, dock, extensiones y la
  terminal Ptyxis se guardan como volcados dconf y se restauran en una máquina
  nueva.
- **Reglas para agentes de IA incluidas**: un único archivo de reglas
  (commits convencionales, manejo de secretos, arranque de proyectos con
  identidad correcta) compartido entre Claude Code, Codex y opencode vía
  `CLAUDE.md`/`AGENTS.md` — [cómo personalizarlo](docs/adaptalo.md#reglas-para-agentes-de-ia).
- **Seguro de usar**: backup automático de todo archivo tuyo que vaya a
  reemplazar, log completo de cada corrida, desinstalador que restaura el
  estado previo, y re-correrlo es siempre idempotente.

## Requisitos previos

- **Linux**: una distro con `dnf`, `apt` o `pacman` (Fedora es la de
  referencia) y poco más — `git` se instala solo si falta.
- **Windows**: winget, PowerShell 7, **Modo de desarrollador** activado (para
  symlinks sin admin) y dos instalaciones manuales previas (VSCode y Python,
  [acá el porqué](docs/instalacion.md#windows)).

Detalle completo por sistema: [docs/instalacion.md](docs/instalacion.md#requisitos-previos).

## Instalación rápida

```bash
# Linux
curl -fsSL https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.sh | bash
```

```powershell
# Windows (desde pwsh 7)
irm https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1 | iex
```

El mismo comando **instala y actualiza** (detecta si el repo ya existe). Qué va
a pasar cuando lo corras:

1. Clona el repo en `~/.dotfiles` y pregunta por el **vault privado** — si no
   tenés uno, un **asistente te crea tus perfiles de git ahí mismo** (nombre,
   email y clave SSH por contexto), o elegí «saltar» y sigue solo con lo público.
2. Te muestra el **selector de herramientas** (nada pre-marcado; `espacio`
   marca, `Enter` confirma, `q` cancela).
3. En Linux pregunta el **shell por defecto** (bash/zsh) si elegiste zsh.
4. Instala, crea los symlinks (con backup de lo tuyo) y aplica el vault si está.
5. Pregunta si querés configurar **AWS SSO** (opcional, solo para
   [Claude Code vía Bedrock](docs/instalacion.md#aws-sso--bedrock-opcional)) —
   decí que no y listo.
6. Valida la instalación y muestra el resumen.

Al terminar: **abrí una terminal nueva** y probá `dothelp`.

> Flags útiles: `--dry-run` (simula sin tocar nada), `--all-tools`,
> `--tools=a,b,c`, `--update-only`. Lista completa en
> [docs/instalacion.md](docs/instalacion.md#flags).

## ¿No sos Kevin?

El repo es personal pero está pensado para adoptarse. Tres niveles:

| Nivel | Qué hacés | Qué obtenés |
|---|---|---|
| **Probarlo** | Correr el instalador y «saltar» el vault | Todo lo público: herramientas, shells, configs |
| **Fork** | Forkear y cambiar `GH_USER` en los installers | El one-liner instala *tu* copia |
| **Vault propio** | Elegir «crear mis perfiles ahora» en el instalador (o `bash ~/.dotfiles/git-profiles.sh`) | Identidades git automáticas por remoto + claves SSH, portables entre máquinas |

La guía paso a paso (incluida la estructura exacta del vault):
**[docs/adaptalo.md](docs/adaptalo.md)**.

## Documentación

| Doc | Qué cubre |
|---|---|
| [Instalación a fondo](docs/instalacion.md) | Requisitos, paso a paso, todos los flags, AWS SSO, troubleshooting |
| [Adaptalo a tu cuenta](docs/adaptalo.md) | Usarlo sin vault, fork, crear tu propio vault, identidades git |
| [Referencia de comandos](docs/comandos.md) | Todas las funciones y aliases, por categoría |
| [Arquitectura](docs/arquitectura.md) | Dos repos, symlink vs copia, dconf, paridad de shells, decisiones de diseño |

## Desinstalar

```bash
bash ~/.dotfiles/uninstall.sh      # pwsh -File ~/.dotfiles/uninstall.ps1 en Windows
```

Muestra un preview, pide confirmación, remueve los symlinks y **restaura los
backups** de tus archivos previos. Opciones en
[docs/instalacion.md](docs/instalacion.md#desinstalación).
