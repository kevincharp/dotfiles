#!/usr/bin/env bash
# catalogo.sh - herramientas que maneja el bootstrap. Lo cargan bootstrap.sh,
# uninstall.sh y test-bootstrap.sh.
#
# "id|grupo|comando|paquete|descripcion"
#   comando: prueba que esta instalada (vacio: caso propio en tool_installed).
#   paquete: lo instala y desinstala el gestor (vacio: caso propio en
#            install_tool, y uninstall no la toca).
# Una herramienta de paquete simple es solo una linea aca.

TOOLS_CATALOG=(
    "neovim|core|nvim|neovim|Editor de terminal"
    "tree-sitter-cli|core|tree-sitter||Compilador de parsers de nvim (requisito de treesitter)"
    "ripgrep|core|rg|ripgrep|Busqueda rapida (picker y buscar/reemplazar de nvim)"
    "fzf|core|fzf|fzf|Fuzzy finder (Ctrl+R)"
    "bash-completion|core|||Autocompletado de bash"
    "oh-my-posh|shell|oh-my-posh||Prompt con tema"
    "zoxide|shell|zoxide||cd inteligente con memoria"
    "eza|shell|eza|eza|Reemplazo moderno de ls"
    "lazygit|shell|lazygit|lazygit|UI de git en terminal"
    "yazi|shell|yazi|yazi|File manager TUI (preview de imagenes/PDF/video)"
    "blesh|shell|||Syntax highlighting en bash (estilo PSReadLine)"
    "zsh|shell|zsh|zsh|Shell zsh (alternativa a bash)"
    "zsh-autosuggestions|shell|||Sugerencias inline en zsh (estilo PSReadLine)"
    "zsh-syntax-highlighting|shell|||Syntax highlighting en zsh (estilo ble.sh)"
    "node|dev|node||Runtime JS + npm"
    "codex|dev|codex||Codex CLI (OpenAI)"
    "claude|dev|claude||Claude Code CLI"
    "opencode|dev|opencode||opencode (SST)"
    "gitleaks|dev|gitleaks|gitleaks|Detector de secretos (pre-commit que activa ginit)"
    "aws|cloud|aws||AWS CLI (Bedrock)"
    "lazyssh|shell|lazyssh||TUI para gestionar conexiones SSH (estilo lazygit)"
    "lazysql|shell|lazysql||TUI para administrar bases de datos (MySQL/PostgreSQL/MSSQL/SQLite)"
    "gh|cloud|gh|gh|GitHub CLI (PRs/issues + clonado del vault)"
    "glab|cloud|glab|glab|GitLab CLI"
    "age|cloud|age|age|Encriptacion de claves SSH"
    "rclone|cloud|rclone|rclone|Sync nube (iCloud Drive, etc.) - ver icloud-mount"
    "firacode|fonts|||FiraCode Nerd Font"
    "ulauncher|apps|ulauncher|ulauncher|Lanzador de apps (estilo Spotlight)"
    "samba|apps|||Compartir carpetas por red (SMB, p.ej. app Archivos de iPhone)"
    "chrome|apps|||Google Chrome (RPM oficial + repo para updates)"
    "firefox|apps|firefox||Firefox (perfiles Personal/Aplicaciones, privacidad por user.js y PWA)"
    "onlyoffice|apps|onlyoffice-desktopeditors|onlyoffice-desktopeditors|Suite ofimatica compatible con Word/Excel/PowerPoint (RPM oficial)"
    "openlogi|apps|||Config de mouse Logitech MX (HID++, alternativa a Options+)"
    "flameshot|apps|flameshot|flameshot|Recortador de pantalla con anotaciones (atajo Super+Shift+S)"
    "remmina|apps|remmina|remmina|Cliente RDP/VNC (conexiones a servers Windows)"
    "obsidian|apps|||Notas en Markdown (Flatpak, sin .rpm oficial)"
    "vscode|apps|code||Editor de codigo (VS Code, repo oficial de Microsoft)"
)

# tool_field <id> <n> - campo n (1 = id) de la herramienta; falla si no existe.
tool_field() {
    local entry
    for entry in "${TOOLS_CATALOG[@]}"; do
        [[ "${entry%%|*}" == "$1" ]] && { cut -d'|' -f"$2" <<< "$entry"; return 0; }
    done
    return 1
}
