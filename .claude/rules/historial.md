---
paths:
  - "shell/**"
---

# Historial estilo PSReadLine (flecha ↑ → lista fzf)

Réplica del **ListView de PSReadLine**: al apretar **↑** se abre `fzf` con el
historial en lista vertical, mostrando **solo el comando** y **filtrado por
prefijo** con lo ya tipeado. No es automático (aparece al apretar ↑, no flota
mientras se tipea) — decisión consciente, alternativas evaluadas en
[`docs/notas-tecnicas.md`](../../docs/notas-tecnicas.md#por-qué-el-historial-estilo-psreadline-y-no-otras-alternativas).

- Implementado en `_fzf_history_widget` (función con paridad bash↔zsh, `zle -N`
  en zsh / `ble-bind -x` en bash vía ble.sh).
- **Ctrl+R** sigue siendo la búsqueda difusa por cualquier parte del comando.
- **`clear-history`** (función con paridad): sin args vacía todo el historial
  (con confirmación); con un patrón borra solo las líneas que matcheen.
