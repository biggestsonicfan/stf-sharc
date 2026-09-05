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

Both files are verified by assembling them and comparing the linked PM image
byte-for-byte against the ROM dumps `cpres1_be.bin` and `cpres2_be.bin`
(big-endian 48-bit PM word streams, as read off the board).

Current status — **both EXACT MATCH**:

```
cpres1.exe  section 'seg_pmco': 0x741C (29724 bytes = 4954 x 48-bit words)
    vs cpres1_be.bin: EXACT MATCH
cpres2.exe  section 'seg_pmco': 0x490E (18702 bytes = 3117 x 48-bit words)
    vs cpres2_be.bin: EXACT MATCH
```

### Toolchain

The GPL **g21k** toolchain — no license required. Everything comes from a
`g21k/binutils` build:

| Tool | Path within `g21k/binutils` | Role |
|------|------------------------------|------|
| `asm21k.exe` | `app/` | macro preprocessor |
| `a21000.exe` | `app/` | assembler → relocatable COFF `.obj` |
| `ld21k.exe`  | `link/` | linker → `.exe` |
| `cdump.exe`  | `cdump/` | COFF section dump |

Also needed:

- `gawk`
- `to_g21k.awk` — the VisualDSP → g21k dialect converter, from the
  [g21k tools](https://github.com/sergev/g21k)
- `extract_obj.py` — slices `seg_pmco` out of the linked `.exe` and diffs it
  against the reference image

> `extract_obj.py` has a `CDUMP` constant at the top pointing at `cdump.exe`.
> Set it to whichever build you have; they work identically.

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

`-l` makes no difference. Only the preprocessor is affected — `a21000`, `ld21k`
and `cdump` are all fine.

### Build and verify

`sharc.ach` places the code segment at its real address, PM block 0, so the
linker resolves every absolute jump/call/dm relocation to `0x20xxx`. Save this
alongside the sources:

```
! Architecture description for the Sega Model 2 SHARC coprocessor (ADSP-21062).
.SYSTEM model2_sharc;
.PROCESSOR=ADSP21062;
.SEGMENT/RAM/PM/BEGIN=0x20000/END=0x24fff   seg_pmco;
.ENDSYS;
```

Then, per file (PowerShell):

```powershell
$G   = '<path to g21k/binutils>'
$AWK = '<path to to_g21k.awk>'
$env:ADI_DSP = '<toolchain root>'    # asm21k/a21000 read this

foreach ($n in 'cpres1','cpres2') {
    # 1. VisualDSP dialect -> g21k dialect
    & gawk.exe -f $AWK "$n.asm" | Set-Content -Encoding ascii "$n.g21k.asm"

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

# 6. extract seg_pmco and compare against the ROM dumps
python extract_obj.py cpres1.exe cpres2.exe
```

Step 5 is essential and easy to skip by accident. `a21000` emits a
*relocatable* object — every absolute jump, call and `dm` address is
segment-relative until `ld21k` adds the `0x20000` base. Comparing the `.obj`
against the ROM will not match; only the linked `.exe` will.

The intermediate `cpres1.g21k.asm` should hash to `299bc81a1ccb9753eed59c9fe7ae8e37`
(MD5), which is a useful early checkpoint if the final compare fails.

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
