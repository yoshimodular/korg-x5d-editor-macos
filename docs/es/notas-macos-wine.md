# Notas sobre Wine en macOS: repintado y procesos

> Documento original en español. Versión en inglés: [`../wine-macos-notes.md`](../wine-macos-notes.md).

Dos cosas que no son específicas de este editor y que probablemente afecten a cualquier aplicación antigua bajo CrossOver.

---

## Bandas sin dibujar

Al cargar un banco o cambiar de programa, algunos recuadros salen cortados a media altura y debajo queda el hueco en blanco. **Cuáles se pierden varía** según lo que se cargue.

**Descartado, con pruebas:**

- **No es la escala.** Ocurre igual al 100% y al 200%.
- **No son las fuentes.** Ocurre con la carpeta `Fonts` vacía.
- **No son contenedores justos de tamaño.** Si lo fueran fallarían siempre los mismos; cambian según el banco.
- **No es `PeekMessageSleep`** de OTVDM.

**Es un repintado incompleto.** El dato que lo demuestra: **minimizar y restaurar la ventana lo arregla**. El programa sabe dibujarlo; el primer dibujado se queda a medias. Al restaurar, Windows invalida todo el área de cliente y se redibuja entera.

### La solución

`redraw.exe` llama a `RedrawWindow` con `RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW` sobre todas las ventanas visibles del proceso — la principal y sus diálogos, que sufren lo mismo.

### Por qué sondea en vez de ir por eventos

Se intentó con **`SetWinEventHook`**, que es la forma correcta en Windows de enterarse desde otro proceso sin sondear. Bajo Wine el enganche **se instala sin dar error y no llega ni un solo evento**. Comprobado provocándolos a propósito: minimizando y restaurando la ventana desde fuera, la sacudida funciona y el vigilante no recibe nada. **Wine no los emite.**

El sondeo cuesta dos llamadas cada 400 ms —el título de la ventana y cuántas hay del proceso—, que cambian al cargar un banco, cambiar de programa o abrir un diálogo. Ni se nota.

---

## Los procesos de Wine no se cierran solos

Al cerrar la aplicación quedan vivos **nueve procesos**: `explorer.exe` (el shell de la botella) y con él `services.exe`, `plugplay.exe`, `rpcss.exe`, `svchost.exe` y dos `winedevice.exe` **girando al 1,5% de CPU cada uno**, indefinidamente y sin ningún tiempo de espera. Con varias sesiones acumuladas se juntan cuatro juegos completos.

Es el diseño de Wine: deja la botella caliente para que el siguiente arranque sea rápido. Pero no la apaga nunca.

**Ninguna de las vías evidentes funciona:**

- `wineserver -k` devuelve error — CrossOver no localiza su servidor por el `WINEPREFIX` estándar.
- `wineboot -k` no los toca.
- `cxreboot` sólo simula un reinicio de Windows.
- CrossOver no tiene ningún comando para apagar una botella.

Además, si se mata el `wineserver` a lo bruto (por ejemplo para forzar que el registro se vuelque a disco), sus servicios quedan **huérfanos**: ya no hay nadie que pueda decirles que salgan, y entonces ni siquiera un `wineserver -k` posterior los alcanza.

### La solución

Matarlos, pero sólo los de la botella que toca. Se identifica a cuál pertenece cada proceso con **`lsof`**:

```sh
for p in $(ps ax | grep "[.]exe" | awk '{print $1}'); do
    lsof -p "$p" 2>/dev/null | grep -q "Bottles/$BOTTLE" && kill -9 "$p"
done
```

Eso hace `scripts/wine-cleanup.sh`, que el lanzador invoca al salir. Medido: 2 procesos antes de abrir → 11 con el editor abierto → **2** cinco segundos después de cerrarlo.
