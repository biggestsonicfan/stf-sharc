# stf-sharc — Sega Model 2 SHARC Coprocessor Firmware

Annotated, reassemblable source for the two ADSP-21062 (SHARC) microcode images
that run on the Sega Model 2 board alongside the i960 main CPU.

Both files carry the **official Sega source-code labels** for every command
handler, and both reassemble **bit-for-bit identically** to the ROM images
dumped from hardware. See [Verification](#verification).

| File | Program | PM words | Bytes | Dispatch table |
|------|---------|---------:|------:|----------------|
| `cpres1.asm` | COP — transform / math engine | 4954 | 29,724 | 136 entries (`0x00`–`0x87`) |
| `cpres2.asm` | GEO — geometrizer / rasteriser feed | 3117 | 18,702 | 32 entries (`0x00`–`0x1F`) |

---

## What these are

The Model 2 board has an i960 main CPU plus a SHARC DSP. The i960 uploads a
microcode image to the SHARC at boot and then drives it by pushing 32-bit
command words into a FIFO. There are two distinct images, for two distinct
roles — they are *not* two revisions of the same program.

### cpres1 — the COP (coprocessor)

The matrix/geometry/collision math engine. The i960 pushes commands to the COP
FIFO and reads results back.

```
i0 = 0x400000   input FIFO   (read  r0=dm(m0,i0) after polling flag0_in)
i1 = 0xC00000   output FIFO  (write dm(m0,i1)=r0 after polling flag1_in)
i2 = 0x30000    dispatch table base
i3 = 0x30300    scratch frame
```

**Command encoding.** A command word replicates its handler index in three
fields, which the firmware validates before dispatching:

```
bits[30:23] == bits[15:8] == bits[7:0] == index N
handler address = DM[0x30000 + N]
```

Equivalently, the opcode word for index `N` is always `N * 0x00800101`
(so index `0x37` → `0x1B803737`). Indices `0x00`–`0x87` have explicit handlers;
`0x88`–`0xFF` are filled with an error halt.

**Current-matrix model.** The COP holds a "current matrix" — a 12-float
column-major 3×3 plus translation — on an 8-deep stack:

```
bone slot DM[i7], 12 floats:  [0..2] col0  [3..5] col1  [6..8] col2  [9..11] T
DM[0x3033F] = i7 (current slot)     DM[0x3033C] = depth (0..7), base DM[0x305A0]
DM[0x30400] = C, the scalar accumulator used by Fn_put_c / add_c / mul_c / ...
```

Most commands read or transform that matrix: `Fn_push_matrix`, `Fn_base_matrix`
(identity), `Fn_x_rot` / `Fn_y_rot` / `Fn_z_rot`, `Fn_trans`, `Fn_point_trans`
(local→world), `Fn_glo_to_loc` (world→local). The rest are scalar/vector math
(`Fn_sin`, `Fn_atan`, `Fn_get_3d_len`, `Fn_regular_vector`), collision
(`Fn_parts_oidasi`, `Fn_calc_coli_flag`), shadows (`Fn_kage_*`), afterimages
(`Fn_zanzou_*`) and display-list submission (`Fn_put_poly`).

### cpres2 — the GEO (geometrizer)

The render stage. It consumes the display list the COP produced, transforms and
projects each polygon's vertices, and streams screen-space polygons to the
rasteriser.

```
i0 = 0x400000   command input  (the COP display list)
i1 = 0x410000   RASTERISER output port
i5 = 0x430000   per-command vertex work area
i6 = 0x30000    dispatch table base (32 entries)
i2 = 0x30020    active 3x4 matrix (set by the MATRIX command)
```

Dispatch index is `(cmd >> 23) & 0x1F`, and its commands are display-list
operations — `OBJECT`, `DIRECT`, `WINDOW`, `TEXDATA`, `TEXUP`, `TEXPARAM`,
`MODE`, `ZSORT`, `FOCAL`, `LIGHT`, `MATRIX`, `END`. Indices `0x11`–`0x1F` alias
`0x01`–`0x0F`, because the index is only 5 bits wide.

---

## The official labels

`cpres1.asm` names all 136 command handlers with their real `Fn_*` symbols from
the Sega COP library source, recovered from a shipped symbol table. Each handler
carries a block like:

```
! ----------------------------------------------------------------------------
! Fn_push_matrix               [official source label]   dispatch 0x01  opcode 0x00800101
!   in=0  out=0    PM 0x20375   copy current bone frame to next stack slot, depth++
! ----------------------------------------------------------------------------
```

and the dispatch table itself is annotated inline.

The symbol table is not stored in dispatch order. Two rules recover the mapping:

1. **Pair reversal** — names come in adjacent pairs holding two consecutive
   dispatch indices `(2k-1, 2k)` in reversed order:
   `Fn_pop_matrix, Fn_push_matrix` → `0x02, 0x01`;
   `Fn_sub, Fn_add` → `0x14, 0x13`; `Fn_x_rot, Fn_scale` → `0x08, 0x07`.
2. **Half-block swap** — past name 7 the table runs in 16-name blocks whose two
   8-name halves are swapped:
   names `[16k+7 .. 16k+14]` ↔ indices `[16k+0x0F .. 16k+0x16]`, and
   names `[16k+15 .. 16k+22]` ↔ indices `[16k+0x07 .. 16k+0x0E]`.
   Name 0 is index `0x00`, name 135 is index `0x87` — the two odd ones out.

136 names, 136 slots, nothing left over on either side. The result is
corroborated throughout by the firmware itself: `Fn_initialize` (`0x00`) resets
the bone-stack depth and pointer; `Fn_get_x/y/z_axis` (`0x56`–`0x58`) read rot
col0/col1/col2; `Fn_put_c/get_c/add_c/sub_c/mul_c/div_c` are exactly the six
`DM[0x30400]` accumulator ops at `0x1B`–`0x20`; `Fn_ken2..ken5` (`0x4B`–`0x4E`)
and `Fn_x_rot_e/y_rot_e/z_rot_e/trans_e` (`0x6C`–`0x6F`) each land on four
consecutive `rts` stubs; `Fn_parts_oidasi` (`0x77`) is the routine IDA names
`epc_oidasi`.

**cpres2 gets none of these labels.** It is a different program with its own
command set; the file carries a header note saying so. The only two library
entry points that reach the GEO at all — `Fn_put_poly` (COP `0x78`) and
`Fn_scrn_clip` (COP `0x7B`) — are cpres1 commands that *build* the display list
cpres2 consumes.

---

## Source dialect

These files are **VisualDSP dialect**: `.SECTION/PM`, `//` comments, no
`.ENDSEG`. That is the original form, and it is what `easm21k` expects.

The g21k pipeline below needs a mechanical conversion first (`.SECTION` →
`.SEGMENT`, `//` → `!`, a closing `.ENDSEG;`, and `.VAR name[] = {...}` →
`.VAR name[N] = ...`). One quirk is worth knowing: g21k's `a21000` has a 32-bit
constant parser, so the converter drops the trailing `00` from 12-hex-digit PM
words in the copyright block —

```
VisualDSP: 0x434F50595200        g21k: 0x434F505952
```

`0x434F50595200` is `"COPYR\0"` as a full 48-bit PM word; PM zero-pads the sixth
byte back, so the linked image is identical either way. **The VisualDSP form
here is the authoritative one**; the g21k form is a downgrade for that assembler.

---

## Verification

The claim these two files make is not that they are equivalent code. It is that
assembling and linking them reproduces the two blobs the program ROM uploads to
the SHARC, **byte for byte** — and that is something a ROM settles by itself.

Current status — **both reproduce the ROM exactly**:

```
cpres1
  image  4954 PM words at 0x20000, byte for byte the ROM's
  found  once in the program ROM, at 0xb6318 — the offset cpres.mjs names

cpres2
  image  3117 PM words at 0x20000, byte for byte the ROM's
  found  once in the program ROM, at 0xbd748 — the offset cpres.mjs names

the disassembly assembles to the two blobs the ROM carries
```

That output is [stf-tools](https://github.com/biggestsonicfan/stf-tools)'
`test-cpres.mjs`, run against this checkout — see
[Round-trip check](#round-trip-check-against-the-rom) below. It is the check
worth running: it needs no extracted reference image, and it will not take
either blob's ROM offset on trust.

### Toolchain

The GPL **g21k** toolchain — no license required. Everything comes from a
`g21k/binutils` build:

| Tool | Path within `g21k/binutils` | Role |
|------|------------------------------|------|
| `asm21k.exe` | `app/` | macro preprocessor |
| `a21000.exe` | `app/` | assembler → relocatable COFF `.obj` |
| `ld21k.exe`  | `link/` | linker → `.exe` |

Also needed: `gawk`, and `to_g21k.awk` — the VisualDSP → g21k dialect
converter, from the [g21k tools](https://github.com/sergev/g21k).

Nothing else. `test-cpres.mjs` reads the COFF section table itself rather than
shelling out to `cdump`, so the check needs only Node and a ROM set.

The recipe below assumes `$G21K` is the `g21k/binutils` directory and `$AWK` is
the path to `to_g21k.awk`.

### Does the assembler need a patch?

**Yes — one, and it is a line-ending bug, not a code change.**

The repo's `asm21k.exe -pp` writes its preprocessed output with **LF** line
endings. `a21000.exe` requires **CRLF** and rejects the first real directive
with a misleading error:

```
%asm21000 - cpres1.cpp, line 62: Syntax Error
Syntax error or missing semicolon at end of previous line.
```

Line 62 is `.SEGMENT/PM seg_pmcode;` and there is nothing wrong with it. The
preprocessed output is otherwise byte-for-byte the same content — same 6253
lines, not one differing line, just 165,660 bytes instead of 171,913.

Two fixes, either works:

- **Convert the `.cpp` to CRLF** between the preprocess and assemble steps
  (used below — keeps everything inside one toolchain).
- **Use an `asm21k.exe` build that already emits CRLF** for the `-pp` step.
  The ADI 21k tools distribution ships one; its `a21000` and `ld21k` are
  interchangeable with the g21k build's.

`-l` makes no difference. Only the preprocessor is affected — `a21000` and
`ld21k` are both fine.

### Build

`sharc.ach` is in this repo. It places the code segment at its real address, PM
block 0, so the linker resolves every absolute jump/call/dm relocation to
`0x20xxx` — and `test-cpres.mjs` reads the link address out of it rather than
assuming `0x20000`, so it is part of the claim, not a convenience.

Per file (PowerShell):

```powershell
$G    = '<path to g21k/binutils>'
$AWK  = '<path to to_g21k.awk>'
$GAWK = 'gawk.exe'                    # or its full path, if not on PATH
$env:ADI_DSP = '<toolchain root>'     # asm21k/a21000 read this

foreach ($n in 'cpres1','cpres2') {
    # 1. VisualDSP dialect -> g21k dialect
    & $GAWK -f $AWK "$n.asm" | Set-Content -Encoding ascii "$n.g21k.asm"

    # 2. preprocess
    & "$G\app\asm21k.exe" -pp -o "$n.raw.cpp" "$n.g21k.asm"

    # 3. LF -> CRLF  (the patch: a21000 will not parse LF-only input)
    $t = [IO.File]::ReadAllText("$PWD\$n.raw.cpp")
    [IO.File]::WriteAllText("$PWD\$n.cpp", ($t -replace "`r`n","`n" -replace "`n","`r`n"))

    # 4. assemble (relocatable .obj)
    & "$G\app\a21000.exe" -l -o "$n" "$n.cpp"

    # 5. link -- resolves absolute addresses against the 0x20000 base
    & "$G\link\ld21k.exe" -a sharc.ach -o "$n.exe" "$n.obj"
}
```

That leaves `cpres1.exe` and `cpres2.exe` in the checkout, which is what the
check below reads. They are gitignored, along with every other intermediate.

### Round-trip check against the ROM

[stf-tools](https://github.com/biggestsonicfan/stf-tools) carries `test-cpres.mjs`,
which holds a fresh assembly against the program ROM itself. Point it at this
checkout with `--disasm` (or `$STF_DISASM`) and give it a ROM set:

```
node test-cpres.mjs --disasm <path to stf-sharc> sfight.zip
```

```
disassembly  ...\stf-sharc
sharc.ach    seg_pmco at PM 0x20000..0x24fff
sfight.zip   program ROM 1048576 bytes

cpres1
  image  4954 PM words at 0x20000, byte for byte the ROM's
  found  once in the program ROM, at 0xb6318 — the offset cpres.mjs names

cpres2
  image  3117 PM words at 0x20000, byte for byte the ROM's
  found  once in the program ROM, at 0xbd748 — the offset cpres.mjs names

the disassembly assembles to the two blobs the ROM carries
```

What it settles, in order: that the linker did what `sharc.ach` asked — one
`seg_pmco`, at that address, inside that window, a whole number of 48-bit PM
words; that there are as many of them as the ROM carries; that they are the same
bytes once the word order is accounted for (a linker writes a PM word big end
first, the ROM holds it low byte first); and finally that the assembled image
turns up in the program ROM **exactly once**, at the offset `cpres.mjs` names.
Neither blob's address is given to it, so a wrong offset and a wrong build
cannot hide each other.

It reads the linked `.exe`, never the `.obj` — `a21000` leaves every absolute
jump, call and `dm` address segment-relative, so an unlinked image differs from
the ROM in every address it carries. Step 5 above is part of the claim.

Two notes specific to using it against *this* repo rather than `m2-hle/disassembly`:

- **`--build` does not work here.** It runs the disassembly's own
  `build_obj.bat`, which this repo does not carry; you get one failure saying so
  while the images themselves still verify. Run the build above by hand first.
- **The staleness warning will not fire.** `cpres.mjs` knows the sources by
  their m2-hle names (`cpres1_ad_annotated_fixed.asm`, `cpres2_ad.asm`), so it
  cannot notice that `cpres1.asm` here is newer than `cpres1.exe`. Rebuild
  before checking; a stale `.exe` beside an edited listing agrees with nothing.

The ROM set is yours to supply — neither repo carries one.

If the check fails, the intermediate `cpres1.g21k.asm` should hash to
`299bc81a1ccb9753eed59c9fe7ae8e37` (MD5) — a useful early checkpoint that
separates a bad dialect conversion from a bad assembly.

### VisualDSP

These files have only been verified through the g21k route above. If you have a
working VisualDSP SHARC toolchain the route is `easm21k -proc ADSP-21062`, then
`linker` with an LDF placing `seg_pmcode` at PM `0x20000`, then dump and compare
as above. No dialect conversion is needed — these files are already in
VisualDSP form.

The g21k route is the stronger check regardless: it reproduces the actual ROM
images, which is the property that matters.

---

## Provenance

Annotations and official labels are generated by `annotate_official.py` (kept
with the wider Model 2 HLE work), which is idempotent and re-runnable. It stamps
both the VisualDSP sources here and the g21k-converted copies, so a rebuild does
not lose the labels.

Adding or editing annotations can never change the output: they are `//`
comments only, and the instruction stream is checked to be byte-identical before
and after. Re-run the build above to confirm.
