---
paths:
  - "yazi/**"
  - "shell/**"
---

# File manager TUI (`yazi/`)

File manager de terminal con preview de imágenes/PDF/video, en **ambos SO**
(opcional, grupo `shell` del selector).

- **Config con path distinto por SO** (misma `yazi/yazi.toml` versionada):
  Linux → symlink a `~/.config/yazi/yazi.toml`; Windows → symlink a
  **`%APPDATA%\yazi\config\yazi.toml`** (NO `~/.config`). Solo redefine el
  **opener** para usar **nvim** al editar texto.
- **`YAZI_FILE_ONE` (solo Windows):** apunta a `file.exe` de Git Bash porque
  yazi no encuentra el binario `file` solo ahí. En Linux no hace falta.
- **Instalación en Fedora vía COPR** `lihaohong/yazi` (no está en repos base).
  Arch lo tiene en repos; Windows es winget `sxyazi.yazi`.
- **Deps de preview = bundle con yazi:** poppler (PDF), ffmpeg (video),
  ImageMagick (imágenes), 7zip (comprimidos) y —solo en Linux— **chafa**
  (Ptyxis no soporta sixel/kitty-protocol, sin chafa no se ve nada de imagen;
  detalle en [`docs/notas-tecnicas.md`](../../docs/notas-tecnicas.md#yazi-por-qué-chafa-y-por-qué-el-path-de-config-difiere-en-windows)).
  Requiere ancho suficiente en la ventana o yazi oculta la columna de preview.
- **Función `y` (cd-on-exit):** wrapper con paridad en los 3 shells. Lanza yazi
  con `--cwd-file` y al salir deja el shell en el último directorio navegado.
