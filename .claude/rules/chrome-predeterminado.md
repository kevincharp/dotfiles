---
paths:
  - "bootstrap.sh"
  - "uninstall.sh"
---

# Chrome duplicado en "Aplicaciones predeterminadas → Web"

`bootstrap.sh` (paso 5) genera un override local de `com.google.Chrome.desktop`
en `~/.local/share/applications/` quitándole los `x-scheme-handler/*` del
`MimeType` (el panel de GNOME no respeta `NoDisplay`, la única palanca real es
el `MimeType`). Se regenera en cada bootstrap; `uninstall.sh` lo limpia. Tras
reaplicar, reabrir Ajustes (el panel cachea la lista). Detalle:
[`docs/notas-tecnicas.md`](../../docs/notas-tecnicas.md#chrome-duplicado-en-aplicaciones-predeterminadas--web).
