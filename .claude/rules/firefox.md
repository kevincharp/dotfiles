---
paths:
  - "firefox/**"
---

# Firefox (`firefox/`)

Navegador de privacidad, **solo Linux** (en Windows no se usa). Grupo `apps` del
selector. Toda la config vive en `firefox/`; el "por qué" (bugs de GNOME, el
perfil predeterminado que se mueve, borrado al cerrar):
[`docs/notas-tecnicas.md`](../../docs/notas-tecnicas.md#firefox-por-qué-dos-perfiles-y-un-desktop-con-perfil-fijo).

- **Dos perfiles, a propósito:** `Personal` (navegador diario) y `Aplicaciones`
  (solo PWA: Teams, Outlook… vía Taskbar Tabs). **Nunca mezclar una PWA y el
  navegador en el mismo perfil**: Firefox corre un proceso por perfil y GNOME
  agrupa por proceso, así que el navegador se cuelga del icono de una PWA.
- **`firefox/apply-profiles.sh`** aplica todo, idempotente (`--dry-run`,
  `--remove`). Resuelve los perfiles **por nombre** desde
  `Profile Groups/*.sqlite` (las carpetas tienen sufijo aleatorio): hay que
  crearlos una vez a mano desde el selector de Firefox, con esos nombres
  exactos. Sale **3 = incompleto** (perfil sin crear, Firefox abierto): es una
  advertencia del bootstrap, no un fallo.
- **Editar el repo, no el perfil:** el `user.js` del perfil lleva una marca y se
  pisa al re-correr. `Aplicaciones` = `user.js` + `user-apps.js` (espejo
  de interfaz, para que los dos perfiles se vean igual).
- **`user.js` se reaplica en cada arranque:** lo que se cambie desde Ajustes
  vuelve al valor del archivo. Para habilitar algo (p. ej. traducciones locales
  del bloque de IA) hay que **quitarlo del repo** y re-correr.
- **El perfil "predeterminado" no sirve para fijar el navegador:** Firefox mueve
  `Default` (`profiles.ini`/`installs.ini`) al último perfil que abrió. Por eso
  el script genera un `.desktop` propio con `-profile` fijo. No vale para el
  `firefox` escrito en terminal.
- **Nombres de preferencias:** cambian entre versiones. Antes de agregar una
  línea al `user.js`, confirmar que existe (`about:config`) y después que se
  aplicó (`about:support` → "Preferencias modificadas", que muestra solo un
  subconjunto).
- **Cookies al cerrar:** `Personal` las borra y las excepciones de
  `cookie-exceptions.txt` funcionan (verificado con GitHub y MercadoLibre).
  `Aplicaciones` hereda el mismo borrado de `user.js`, pero el script no escribe
  en un perfil con Firefox abierto: tras sumar un origen, cerrar las PWA y
  re-correrlo. Si se pierden sesiones, diagnóstico en las notas técnicas.
- **`$BROWSER` = `firefox-personal` (solo Linux):** `apply-profiles.sh` enlaza
  `~/.local/bin/firefox-personal` -> `firefox/open-personal.sh`, y bashrc/zshrc
  lo exportan como `BROWSER`. Abre las URLs de la terminal (`aws sso login`,
  `gh auth login`) en el perfil Personal y con la salida descartada: Firefox
  lanzado desde la terminal vuelca ahi sus logs (el 400 de Safe Browsing es de
  Firefox/Google, inofensivo). En Windows no pasa, no hace falta.
- **Sqlite solo con Firefox cerrado** (excepciones de cookies, zoom): el script
  lo detecta y lo saltea con aviso.
- **Pendiente a propósito:** `network.trr.excluded-domains` vacío (dominios
  internos de la VPN); extensiones (uBlock Origin, Proton Pass) a mano; Firefox
  Sync intacto.
