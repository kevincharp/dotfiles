---
paths:
  - "gnome/**"
---

# Capturas de pantalla (Flameshot + nativo de GNOME)

Conviven **dos** recortadores, a propósito (paridad parcial con Windows):

- **Flameshot** (recortador con anotaciones) → atajo **`Super+Shift+S`** (el mismo
  que el recorte de Windows). Vive en `gnome/media-keys.dconf` como `custom3`.
  Flameshot NO es una app con ventana — es un daemon de bandeja, se usa **solo
  por atajo** (`flameshot gui`).
- **Captura nativa de GNOME** → sigue en **`Print`** (intacta): en el notebook
  Lenovo `Print` depende de `Fn`, así que se dejó como estaba.
- El teclado del Lenovo además dispara Flameshot con **`Fn+F10`** por un keysym
  de hardware (no es un atajo de dconf, no se versiona).
