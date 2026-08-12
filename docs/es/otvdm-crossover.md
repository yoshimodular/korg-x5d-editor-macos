# El editor de Korg de 16 bits en CrossOver, con MIDI

> Documento original en español. Versión en inglés: [`../otvdm-crossover.md`](../otvdm-crossover.md).

`SE05.EXE` es un ejecutable **NE de Windows 3.x (16 bits)**, no de Win95 como sugiere su época. Eso descarta Wine directamente —no tiene soporte de 16 bits utilizable en ARM— y también Parallels en Apple Silicon, porque Windows 11 ARM no trae NTVDM.

**Sí funciona** con **OTVDM/winevdm**, que reimplementa el subsistema Win16 como una aplicación de **32 bits** y por tanto corre bajo Rosetta 2. Ventana nativa, ratón del sistema y CoreMIDI directo. No hace falta emular un PC entero.

## Las cuatro piezas

Las cuatro son necesarias:

1. **`msvbvm60.dll`** (runtime de VB6) — extraído del CAB de `vbrun60sp6.exe` **sin ejecutarlo**, con el `cabextract` que trae CrossOver.
2. **`MFC40.DLL`** — de `BASE4.CAB` de un CD de Windows 98.
3. **Los 15 `api-ms-win-crt-*.dll` de 32 bits** — no vienen en el VC++ moderno, que da por hecho que Windows 10 los trae. Hay que sacarlos del **VC++ 2015 RTM x86**, extrayendo el bundle con `cabextract` y renombrando los `api_ms_..._.dll` (guiones bajos) a guiones.
4. **La clave:** Wine trae **50 módulos propios de 16 bits** (`krnl386.exe16`, `mmsystem.dll16`, `user.exe16`…) que se cargan **con prioridad sobre los de OTVDM** y en ARM no pueden funcionar. Hay que forzarlos todos a `native` en `HKCU\Software\Wine\DllOverrides`, con las tres variantes de nombre (`mmsystem.dll16`, `mmsystem.dll`, `mmsystem`).

Sólo con `krnl386` el programa arranca pero **no ve ningún puerto MIDI**. El que lo arregla es `mmsystem`.

## Trampas que cuestan tiempo

- **El `wineserver` mantiene el registro en memoria** y lo reescribe al cerrarse, pisando los cambios hechos por fuera. Hay que pararlo y esperar el volcado entre escrituras.
- **`regedit /S` no importa ficheros `.reg` de forma fiable** aquí. Usar `reg add`.
- **Las entradas `--type raw` de `cxmenu` se ejecutan en la shell de macOS**, no en Wine, así que un comando `C:\...` no funciona: hay que apuntar a un script nativo o copiar un `.app` propio.

## Escalado

Se sube con `LogPixels` (96 = 100%, 192 = 200%) en `HKCU\Control Panel\Desktop` y `HKCU\Software\Wine\Fonts`. El script `dpi.sh` lo hace.

Eso agranda la fuente, no la imagen. Los diálogos escalan bien porque Windows los mide en unidades relativas a la fuente; la ventana principal, que el programa dibuja a mano en píxeles, no. Ni Wine ni OTVDM saben ampliar la imagen ya dibujada, que sería lo único que respetaría la maqueta.

## No instalar fuentes de Windows

Se probó copiar las 46 originales de Windows 98 para arreglar textos cortados y **empeora**: el editor calcula la altura de sus paneles a partir de las métricas del texto, y con otra fuente algunos bloques se dibujan a medias. Con dejar sólo cuatro seguía roto. **La carpeta `Fonts` de la botella debe estar vacía.**

## Qué falla y qué no

| | |
|---|---|
| Arranque, edición, cierre | bien |
| Puertos MIDI, recepción | bien |
| Volcados de banco | bien, **con el proxy de winmm** |
| Algunos textos cortados | queda así; son cadenas concretas en sitios estrechos |
| Bandas sin dibujar | resuelto con `redraw.exe` |
