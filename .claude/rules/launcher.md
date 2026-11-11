---
paths:
  - "ulauncher/**"
  - "flowlauncher/**"
  - "gnome/media-keys.dconf"
---

# Launcher de apps (Ulauncher / Flow Launcher)

Lanzador estilo Spotlight, **uno por SO** (ninguno cruza): Linux → Ulauncher
(catálogo `apps`), Windows → Flow Launcher (winget, grupo `extras`).

**Flow Launcher** (`flowlauncher/`): config por **symlink**, gateado por la key
`flowlauncher` (detectado por la carpeta `%LOCALAPPDATA%\FlowLauncher`).

- `flowlauncher/Settings.json` → `%APPDATA%\FlowLauncher\Settings\Settings.json`
  (hotkey, tema, idioma, plugins activos) y un `Settings.json` por plugin nativo
  en `flowlauncher/Plugins/<plugin>/` (p. ej. los buscadores de Web Searches).
  Lo que se cambie desde la GUI de Flow Launcher cae en el repo a través del
  symlink — igual que Windows Terminal.
- **Se versiona solo la config**, no el historial (`History.json`,
  `UserSelectedRecord.json`) ni los `.bak`: son ruido de uso.
- Ruido esperable en el diff: posición de ventana (`WindowLeft/Top`,
  `SettingWindow*`) y `Version` de los plugins cambian solos con el uso y las
  actualizaciones. Es config de la máquina que queda versionada; aceptado.
- Plugin nuevo (instalado desde Plugins Manager): copiar su `Settings.json` a
  `flowlauncher/Plugins/<carpeta>/` y re-correr bootstrap para linkearlo.
- Verificado solo con `bootstrap.ps1 -DryRun`; el symlink real se prueba al
  correr bootstrap en una PC (necesita Modo de desarrollador).

Ulauncher tiene tres piezas, versionadas distinto:

- **Config** (`ulauncher/settings.json`, `shortcuts.json`) → **symlink** a
  `~/.config/ulauncher/`.
- **Atajo `Ctrl+Space`** → NO va en `ulauncher/`. Vive en
  `gnome/media-keys.dconf` (`custom1` → `ulauncher-toggle`): en Wayland el
  hotkey interno de Ulauncher no funciona. Reversionar con `gnome-save`.
- **Autostart** (`ulauncher/autostart.desktop`) → **copia** (no symlink) a
  `~/.config/autostart/`: GNOME reescribe ese `.desktop` desde su GUI.
- **Temas** (`ulauncher/user-themes/`) → **symlink**. Trae Liquid Glass
  (dark/light), vendorizado desde [kayozxo/ulauncher-liquid-glass]. El vidrio
  esmerilado real lo da la extensión GNOME **Blur My Shell**, config en
  `gnome/blur-my-shell.dconf`. En Wayland una extensión recién instalada no
  carga hasta reiniciar sesión. **Hoy ese vidrio no está activo:** el blur de
  `applications` está en `false` y el paquete de Fedora 45 trae Blur My Shell
  sin su carpeta `styles/`
  ([notas](../../docs/notas-tecnicas.md#dock-y-barra-superior-en-gnome-51-dash-to-dock-blur-my-shell-y-sus-trampas)).
