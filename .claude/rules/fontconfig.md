---
paths:
  - "fontconfig/**"
---

# Emojis a color en Chrome (`fontconfig/`)

`fontconfig/fonts.conf` → **symlink** a `~/.config/fontconfig/fonts.conf`.
Fuerza los emoji a color en Chrome/Chromium (Chrome no usa el alias genérico
`emoji` de fontconfig, matchea por cobertura de glifo y sin esto ganan fuentes
monocromáticas). Detalle y comando de verificación:
[`docs/notas-tecnicas.md`](../../docs/notas-tecnicas.md#emojis-a-color-en-chrome-por-qué-fontconfig-y-no-basta-con-instalar-la-fuente).

- Arregla solo el **renderizado**. La **entrada** de emoji se resuelve con
  `Super+.` → GNOME Caracteres (`custom4` en `gnome/media-keys.dconf`), copiar
  y pegar con `Ctrl+V` — Wayland prohíbe que una app simule teclado en otra,
  así que ningún picker auto-inserta.
