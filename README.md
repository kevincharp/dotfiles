# dotfiles

Mi entorno de desarrollo en Linux (Fedora) y Windows: shells, terminal, git,
Neovim, escritorio GNOME y el harness para trabajar con agentes de IA. Mismas
funciones y mismo prompt en bash, zsh y PowerShell.

![Captura del entorno](screenshots/2026-07-09_22-31.png)

Lo sensible (claves SSH cifradas con age, identidades git, tokens) vive en un
segundo repo privado, `dotfiles-vault`. Acá no hay nada secreto.

## Instalar o actualizar

```bash
# Linux
curl -fsSL https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.sh | bash
```

```powershell
# Windows
irm https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1 | iex
```

Clona el repo en `~/.dotfiles`, clona el vault, muestra el selector de
herramientas, crea los symlinks y valida. Re-correrlo es idempotente. No hace
backups: un archivo en el destino de un symlink se reemplaza.

Flags y detalle: [docs/instalacion.md](docs/instalacion.md).

## Documentación

| Doc | Qué cubre |
|---|---|
| [Instalación](docs/instalacion.md) | Requisitos, pasos, flags, AWS SSO, problemas comunes |
| [Comandos](docs/comandos.md) | Funciones y aliases por categoría (`dothelp` en la terminal) |
| [Arquitectura](docs/arquitectura.md) | Dos repos, symlink o copia, dconf, paridad de shells |
| [Playbook de desarrollo](docs/playbook-desarrollo.md) | Flujo de trabajo con agentes |
| [Catálogo de skills](docs/agent-skills-catalogo.md) | Plugins y skills habilitados |
| [Radar de skills](docs/skills-radar.md) | Lo evaluado, instalado o no |
| [Notas técnicas](docs/notas-tecnicas.md) | El porqué de las reglas de `AGENTS.md` |

## Desinstalar

```bash
bash ~/.dotfiles/uninstall.sh      # pwsh -File ~/.dotfiles/uninstall.ps1 en Windows
```
