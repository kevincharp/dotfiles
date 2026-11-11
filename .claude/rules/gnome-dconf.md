---
paths:
  - "gnome/**"
  - "terminal/**"
---

# dconf NO es archivo (Ptyxis / GNOME)

Ptyxis y GNOME guardan su config en la base de datos `dconf`, no en archivos, así
que **no se symlinkean**. Se sincronizan con helpers definidos en `bashrc`:

- `ptyxis-save` / `gnome-save`: sistema → repo (volcar al `.dconf` versionado).
- `ptyxis-load` / `gnome-load`: repo → sistema.

Tras cambiar atajos/tema por la GUI, hay que correr el `*-save` para versionarlo.
Editar el `.dconf` a mano no aplica nada hasta hacer `*-load`.

**Ptyxis siempre con `--new-window`** (atajo `custom0` en
`gnome/media-keys.dconf`, y el override del `.desktop` sin `DBusActivatable`):
sin eso, la activación D-Bus reutiliza una ventana en otro escritorio y GNOME
no cambia de workspace — parece que el atajo no hace nada. Por qué:
[`docs/notas-tecnicas.md`](../../docs/notas-tecnicas.md#ptyxis-por-qué---new-window-es-obligatorio).
