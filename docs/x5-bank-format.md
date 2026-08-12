# The `.X5` bank format and Korg's System Exclusive

Worked out by measuring the files. It is not documented anywhere.

*(Spanish original: [`es/formato-x5.md`](es/formato-x5.md).)*

## The `.X5` / `.05R` banks

They are **always 30891 bytes** and hold the data **raw, exactly as it travels
over SysEx**, only unpacked:

| Area | Offset | Size | Total |
|---|---:|---:|---:|
| Editor header (not transmitted) | 0 | 862 | 862 |
| 100 programs | 862 | 136 each | 13,600 |
| 100 combinations | 14,462 | 164 each | 16,400 |
| Global data | 30,862 | 29 | 29 |
| | | | **30,891** |

Every program and every combination starts with its **name in 10 ASCII
characters**, which lets you check the alignment at a glance: in `M1.X5`,
program 0 is `FilmScore`, program 1 is `Pankala`, program 99 is `Please~~~~`;
combination 99 is `Surprise!!`.

## The SysEx

Model `0x36` = 05R/W · X5 · X5D.

```
F0 42 3n 36 <func> <packed data> F7
```

`n` = global MIDI channel − 1.

| Function | Contents |
|---|---|
| `0x40` | current program |
| `0x49` | current combination |
| `0x4C` | all programs |
| `0x4D` | all combinations |
| `0x55` | global data |
| `0x68` | multi setup |

## 7→8 packing

For every 7 raw bytes, one byte is emitted carrying bit 7 of each of those 7,
followed by the 7 bytes with bit 7 cleared. **Bit *j* corresponds to byte *j*,
LSB first.**

Transmitted size = `N + ceil(N/7)`.

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

## How it was verified

Two independent checks close it:

**The sizes match.** The SysEx messages inside the `.MLT` files fit the formula
exactly: 238 transmitted → 208 raw = 16 parts × 13 bytes for the multi setup,
and 34 → 29 for the global block, which is precisely the size of the tail of an
`.X5` bank.

**The bit order comes out 95 to 5.** The 29 global bytes appear **packed** in
the `.MLT` files and **raw** in the tail of the `.X5` files: they are the same
structure. Comparing the high-bit pattern of the 158 unpacked multis against
that of the real banks, LSB-first is right in 95 cases and MSB-first in 5.

## The `.MLT` files

They are **Standard MIDI Files** (format 0, one track) wrapping two SysEx
messages: the multi setup (`0x68`) and the global data (`0x55`).

**Trap:** the `MTrk` header declares **one byte more** than the file actually
contains. The end has to be clamped to `len(file)` or the parser runs off the
end.

## Note

`SE05.EXE` contains no SysEx templates — zero occurrences of `F0 42` — because
it builds them in code. The format cannot be lifted out of the binary.

The `x5syx` and `mltsyx` converters implement all of the above. By default they
**omit the global data**, because it would overwrite the synthesizer's tuning
and MIDI settings.
