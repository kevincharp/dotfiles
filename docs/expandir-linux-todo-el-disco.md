# Expandir Linux a todo el disco (post-borrado de Windows)

> Tarea de mantenimiento puntual, **no** parte del bootstrap. Este doc es la guía
> autocontenida para terminar de migrar el dualboot a Linux-only en el notebook
> Lenovo (disco NVMe WD Green SN350 1TB).
>
> **Estado al escribir esto (2026-06-28):** Windows ya fue eliminado (sus
> particiones borradas). Falta que Linux **use** el espacio liberado. Hasta hacer
> el Paso 2, `df` sigue mostrando ~194 GB en `/home` — es correcto, el hueco está
> *sin asignar*.

---

## 0. Contexto: cómo está el disco AHORA

```
Disco /dev/nvme0n1 — 932 GiB — GPT — arranque UEFI

Núm  Rango (GiB)      Tamaño   Qué es                         ¿Tocar?
 1   0,00 – 0,20      0,2 GiB  EFI System Partition (fat32)   ❌ NO (arranca Fedora)
     0,20 – 735       ~735 GiB ESPACIO LIBRE (era Windows)    ← acá va el espacio
 5   735  – 737       2,0 GiB  /boot (ext4)                   se mueve
 6   737  – 931       193 GiB  Linux: LUKS2 → btrfs           se mueve + se expande
     931  – 932       0,7 GiB  ESPACIO LIBRE                  (sobra, ignorar)
```

Layout visual:

```
[EFI 0.2][      LIBRE ~735 GiB      ][/boot 2][ Linux 193 ][libre 0.7]
  p1            (hueco de Windows)      p5         p6
```

El problema central: **el hueco quedó a la IZQUIERDA de Linux**, y btrfs/LUKS solo
crecen hacia la derecha. Por eso no alcanza con "expandir": hay que **mover** /boot
y Linux hacia la izquierda primero, y recién ahí expandir Linux sobre el hueco.

### Datos de identificación (NO cambian al mover — por eso fstab/crypttab NO se editan)

| Elemento            | Identificador |
|---------------------|---------------|
| LUKS container (p6) | UUID `fe4629b5-bc16-4377-ab6f-f40041bd75c9` |
| btrfs interno       | UUID `6e5dae60-3a85-4477-8e50-f1021e8e08db` (subvols `root` + `home`, `compress=zstd:1`) |
| /boot (p5)          | UUID `8a2c70fc-7f89-4d8f-a5bb-1db42d0cb1f4` (ext4) |
| EFI (p1)            | UUID `A2BF-61A6` (fat32) |
| Mapper abierto      | `luks-fe4629b5-...` → `/dev/mapper/...` → btrfs en `/` y `/home` |

> Mover una partición **conserva su UUID** (vive en el header del FS/LUKS, viaja con
> los datos). Como `/etc/fstab` y `/etc/crypttab` referencian por UUID, **no hay que
> editarlos**. Esa es la garantía de que "todo queda como está".

---

## 1. Objetivo final

```
[EFI 0.2][/boot 2][          Linux LUKS+btrfs ~928 GiB          ]
  p1        p5                       p6 (expandida)
```

Una sola partición Linux con (casi) todo el disco. EFI y /boot **siguen siendo
particiones aparte**: son obligatorias para arrancar, no son "el disco partido".
El sistema queda **idéntico** (apps, configs, usuario, todo): solo cambia dónde
está físicamente y cuánto ocupa.

---

## 2. Antes de empezar — REQUISITOS

- [ ] **Notebook ENCHUFADA a corriente** todo el proceso (no a batería). Un corte a
      mitad del movimiento de datos cifrados puede corromper el filesystem.
- [ ] **Backup de lo importante** a un disco externo o nube. No porque se planee
      fallar, sino porque tocar particiones siempre puede salir mal. Es la red.
      (Usás solo ~23 GB, así que es rápido.) Lo crítico ya está versionado:
      este repo de dotfiles + el `dotfiles-vault`.
- [ ] **Pendrive ≥ 4 GB** para el medio de arranque (se borra entero al grabarlo).
- [ ] **Tener esta guía accesible desde OTRA pantalla** (celular, otra compu): durante
      la operación vas a estar en el sistema del USB, sin esta sesión de Claude viva.
- [ ] **Recordar la passphrase de LUKS.** Vas a tener que escribirla para
      desbloquear el disco en el entorno live.

> ⚠️ **Tiempo y riesgo honestos:** mover ~195 GB cifrados tarda ~30–60 min y es la
> operación de mayor riesgo de toda la migración. Es segura **si no se interrumpe**.

---

## 3. Crear el medio de arranque (desde tu Fedora actual, ANTES de reiniciar)

Recomendado: **GParted Live** (ISO chico, herramienta dedicada con soporte LUKS,
es lo más a prueba de balas para esta tarea). Alternativa: Fedora Workstation Live
(más pesado; trae GNOME pero hay que instalar GParted a mano en la sesión live).

### Opción A — GParted Live (recomendada)

1. Descargá el ISO desde <https://gparted.org/download.php> (amd64).
2. Identificá tu pendrive (¡ojo de no equivocarte de disco!):
   ```bash
   lsblk -do NAME,SIZE,MODEL,TRAN
   ```
   El NVMe interno es `nvme0n1`. El pendrive será algo como `sda` (TRAN=usb).
3. Grabá el ISO al pendrive (reemplazá `sdX` por tu pendrive REAL):
   ```bash
   sudo dd if=~/Descargas/gparted-live-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
   O usá **GNOME Disks** → "Restaurar imagen de disco" (gráfico, menos riesgo de
   tipear mal el dispositivo).

### Opción B — Fedora Live
Grabás el ISO de Fedora Workstation igual que arriba. En la sesión live, antes de
abrir GParted: `sudo dnf install -y gparted`.

---

## 4. Arrancar desde el USB

1. Reiniciá. Entrá al menú de arranque del Lenovo (suele ser **F12** al encender;
   si no, **Enter** → menú, o **F1/F2** para BIOS).
2. Elegí el pendrive USB (no el "Windows Boot Manager" ni el disco interno).
3. En GParted Live: aceptá los defaults (teclado/idioma) hasta que abra el escritorio
   con GParted ya corriendo.
4. Arriba a la derecha, asegurate de tener seleccionado **`/dev/nvme0n1`** (el disco
   de 932 GiB), no el pendrive.

---

## 5. La operación en GParted (el corazón de la tarea)

Vas a ver: `p1` (EFI), un bloque grande **unallocated** (~735 GiB), `p5` (/boot),
`p6` (un candado 🔒 = LUKS), y un pedacito unallocated al final.

> GParted encola operaciones y recién las ejecuta al apretar **Apply** (✓ verde).
> Hasta entonces no toca nada: podés revisar y deshacer con seguridad.

### Paso 5.1 — Desbloquear el LUKS
Click derecho en `p6` (la del candado) → **Unlock** / **Open Encryption** →
escribí tu passphrase. Ahora GParted ve el btrfs interno y puede redimensionarlo.

### Paso 5.2 — Mover `/boot` (p5) hacia la izquierda
1. Click derecho en `p5` → **Resize/Move**.
2. En el diagrama, **arrastrá el bloque del todo a la izquierda**, hasta pegarlo
   contra `p1` (EFI). NO cambies su tamaño (sigue 2 GiB), solo su posición
   ("Free space preceding" → 0).
3. **Resize/Move** para encolar.

Resultado encolado: `EFI | /boot | [LIBRE ~735] | Linux | [libre 0.7]`

### Paso 5.3 — Mover Linux (p6) hacia la izquierda
1. Click derecho en `p6` → **Resize/Move**.
2. Arrastrá el bloque **a la izquierda** hasta pegarlo contra `/boot`
   ("Free space preceding" → 0). De momento NO lo agrandes (primero moverlo).
3. **Resize/Move** para encolar.

Resultado encolado: `EFI | /boot | Linux | [LIBRE ~736]`

### Paso 5.4 — Expandir Linux sobre el espacio libre
1. Click derecho en `p6` → **Resize/Move**.
2. **Arrastrá el borde DERECHO hasta el final** del disco ("Free space following"
   → 0). GParted agrandará la partición, el contenedor LUKS y el btrfs interno.
3. **Resize/Move** para encolar.

> 💡 Si GParted permite combinar 5.3 y 5.4 en un solo paso (mover izquierda + estirar
> derecha a la vez), mejor — menos operaciones. Si no, hacelos separados como arriba.

### Paso 5.5 — Aplicar
1. Revisá la lista de operaciones encoladas (abajo). Deberías ver mover /boot,
   mover crypt/Linux, y resize del crypt + btrfs.
2. **Apply** (✓ verde) → confirmá.
3. **ESPERÁ sin tocar nada.** El mover de ~195 GB es lo lento. Puede parecer
   colgado: es normal, dejalo terminar. NO cierres, NO apagues, NO desenchufes.

### Paso 5.6 — Cerrar
Cuando diga "All operations successfully completed": cerrá GParted, **apagá** desde
el menú del live, **sacá el pendrive**, y encendé normal.

---

## 6. Verificación (de vuelta en tu Fedora normal)

Debería arrancar igual que siempre (te pedirá la passphrase como de costumbre).
Después, comprobá que el espacio está:

```bash
# /home y / deberían mostrar ~900+ GiB de tamaño ahora:
df -hT /home /

# El btrfs ve todo el dispositivo:
sudo btrfs filesystem usage /

# Layout del disco: p6 ahora enorme, sin hueco grande:
sudo parted /dev/nvme0n1 unit GiB print free
```

> Si por algún motivo el btrfs no creció pero la partición sí (raro, GParted suele
> hacerlo solo), forzalo en caliente:
> ```bash
> sudo btrfs filesystem resize max /
> ```

---

## 7. Limpieza final (opcional)

```bash
# Quitar la entrada "Windows Boot Manager" del menú de GRUB:
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# (Opcional) borrar los restos de Windows en la EFI para recuperar unos MB:
sudo ls /boot/efi/EFI/        # ver qué hay
# sudo rm -rf /boot/efi/EFI/Microsoft   # solo si confirmás que ya no booteás Windows
```

---

## 8. Si algo sale mal (troubleshooting)

| Síntoma | Qué hacer |
|---|---|
| **No bootea / no pide passphrase / kernel panic** | Arrancá de nuevo desde el USB. Tus datos siguen en el LUKS (mover no los borra). Como fstab/crypttab usan UUID y el UUID no cambió, lo normal es que arranque bien. Si no, abrí el LUKS desde el live (`cryptsetup open /dev/nvme0n1pN luks`), montá y revisá `/etc/fstab`. Peor caso: restaurás el backup. |
| **GParted falla a mitad ("operation failed")** | NO sigas a ciegas. Anotá el mensaje exacto. Mientras no se haya completado un *resize* corrupto, los datos están. Sacá foto del error y, de vuelta online, traémelo. |
| **GParted no ofrece "Unlock" en p6** | La versión es vieja / sin soporte LUKS. Usá GParted Live actual (no una Fedora vieja). |
| **`df` sigue mostrando 194 GB tras reiniciar** | Corré `sudo btrfs filesystem resize max /` (sección 6). |
| **El movimiento parece colgado >1h** | Para 195 GB en NVMe debería ser bastante menos, pero NO interrumpas a menos que estés segurísimo de que murió. Interrumpir es lo único que corrompe. |

---

## 9. Pendiente aparte: auto-desbloqueo con TPM (OPCIONAL, otro día)

Tema independiente de la expansión. El notebook tiene **TPM 2.0** y LUKS2, así que
se puede enrolar la llave en el TPM para **arrancar sin tipear la passphrase**
manteniendo el disco cifrado. Resumen (hacer DESPUÉS de la expansión, sobre la
partición final):

```bash
# 1. Enrolar (pide la passphrase actual una última vez; queda como fallback):
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p6

# 2. Agregar 'tpm2-device=auto' a las opciones de la línea en /etc/crypttab
#    (queda: ...none discard,x-initrd.attach,tpm2-device=auto)

# 3. Regenerar initramfs:
sudo dracut -f

# 4. Reiniciar: debería NO pedir passphrase. Si el TPM no suelta la llave
#    (p.ej. cambió Secure Boot/firmware), cae al fallback de passphrase.
```

> ⚠️ Atar al PCR 7 (estado de Secure Boot): si cambiás Secure Boot o actualizás
> firmware, el TPM deja de soltar la llave y vuelve a pedir passphrase. Por eso
> **nunca olvides la passphrase** aunque uses TPM.

---

## Resumen del flujo

```
AHORA (sesión Claude)         Live USB (solo, con esta guía)      Vuelta a Fedora
- doc commiteado+pusheado  →  - mover /boot + Linux           →  - df / btrfs usage
- backup + pendrive listos    - expandir Linux                   - grub2-mkconfig
                              - sin Claude vivo                   - (opcional) TPM
```
