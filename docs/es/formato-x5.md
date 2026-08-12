# Formato de los bancos .X5 y del System Exclusive de Korg

> Documento original en español. Versión en inglés: [`../x5-bank-format.md`](../x5-bank-format.md).

Deducido midiendo los ficheros. No está documentado en ninguna parte.

## Los bancos `.X5` / `.05R`

Miden **siempre 30891 bytes** y guardan los datos **en crudo, tal cual viajan por sysex**, sólo que sin empaquetar:

| Zona | Offset | Tamaño | Total |
|---|---:|---:|---:|
| Cabecera del editor (no se transmite) | 0 | 862 | 862 |
| 100 programas | 862 | 136 c/u | 13.600 |
| 100 combinaciones | 14.462 | 164 c/u | 16.400 |
| Datos globales | 30.862 | 29 | 29 |
| | | | **30.891** |

Cada programa y cada combi empieza por su **nombre en 10 caracteres ASCII**, lo que permite verificar el alineamiento de un vistazo: en `M1.X5` el programa 0 es `FilmScore`, el 1 `Pankala`, el 99 `Please~~~~`; la combi 99 es `Surprise!!`.

## El sysex

Modelo `0x36` = 05R/W · X5 · X5D.

```
F0 42 3n 36 <func> <datos empaquetados> F7
```

`n` = canal MIDI global − 1.

| Función | Contenido |
|---|---|
| `0x40` | programa actual |
| `0x49` | combinación actual |
| `0x4C` | todos los programas |
| `0x4D` | todas las combinaciones |
| `0x55` | datos globales |
| `0x68` | multi setup |

## Empaquetado 7→8

Por cada 7 bytes crudos se emite 1 byte que lleva los bits 7 de esos 7, seguido de los 7 bytes con el bit 7 a cero. **El bit *j* corresponde al byte *j*, LSB primero.**

Tamaño transmitido = `N + ceil(N/7)`.

```python
def pack(data):
    out = bytearray()
    for i in range(0, len(data), 7):
        grp = data[i:i+7]
        msb = 0
        for j, b in enumerate(grp):
            if b & 0x80: msb |= 1 << j
        out.append(msb)
        out.extend(b & 0x7F for b in grp)
    return bytes(out)
```

## Cómo se verificó

Dos comprobaciones independientes lo cierran:

**Los tamaños cuadran.** Los sysex dentro de los ficheros `.MLT` encajan exactamente con la fórmula: 238 transmitidos → 208 crudos = 16 partes × 13 bytes para el multi setup, y 34 → 29 para el bloque global, que es justo el tamaño de la cola de un banco `.X5`.

**El orden de bits sale por 95 a 5.** Los 29 bytes globales aparecen **empaquetados** en los `.MLT` y **en crudo** en la cola de los `.X5`: son la misma estructura. Comparando el patrón de bits altos de los 158 multis desempaquetados con el de los bancos reales, el orden LSB-first acierta en 95 casos y el MSB-first en 5.

## Los ficheros `.MLT`

Son **Standard MIDI Files** (formato 0, una pista) que envuelven dos sysex: el multi setup (`0x68`) y los datos globales (`0x55`).

**Trampa:** la cabecera `MTrk` declara **un byte más** de los que tiene el fichero. Hay que acotar el final a `len(fichero)` o el parser se sale.

## Nota

`SE05.EXE` no contiene plantillas de sysex — cero ocurrencias de `F0 42` — porque las construye por código. No se puede sacar el formato del binario.

Los conversores `x5syx` y `mltsyx` implementan todo esto. Por defecto **omiten los datos globales**, porque sobrescribirían la afinación y los ajustes MIDI del sintetizador.
