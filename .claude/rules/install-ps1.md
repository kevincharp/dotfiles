---
paths:
  - "install.ps1"
---

# `install.ps1` debe ser ASCII puro (lo lee PowerShell 5.1)

`install.ps1` es el **único** script que corre bajo la consola por defecto de
Windows (5.1), porque su primer trabajo es cortar si no hay pwsh 7. PowerShell
5.1 lee los `.ps1` como **ANSI (cp1252)**, no UTF-8: un carácter no-ASCII
dentro de un string puede decodificarse como bytes que **cierran el string** y
tiran un error de parseo del archivo entero — el gate ni llega a ejecutarse.
Detalle completo (el bug de `iex`/`exit` y el de leer stdin en 5.1):
[`docs/notas-tecnicas.md`](../../docs/notas-tecnicas.md#installps1-el-problema-de-fondo-irm--iex).

- En `install.ps1`: **nada de no-ASCII en strings** (usar `-` en vez de `—`). En
  comentarios es inofensivo.
- Los iconos se construyen por código (`[char]0x2713`), no como literales, y
  caen a ASCII si no hay pwsh 7 + UTF-8.
- Verificar el gate con `powershell -NoProfile -File install.ps1` (5.1): debe
  imprimir el mensaje legible y salir 1. `bootstrap.ps1` no tiene la
  restricción: solo lo invoca pwsh 7.
- Bajo `irm | iex`, `exit` mata la terminal (no el script) — por eso
  `install.ps1` se re-ejecuta solo como archivo (`-File`) antes de usar
  `exit`. No tocar ese mecanismo sin leer la nota completa.
- Leer stdin bajo `irm | iex` en PowerShell 5.1 requiere abrir `CONIN$` con
  `CreateFileW` (`FileStream` normal no puede) — mecanismo frágil, no
  reescribir sin leer la nota completa.
