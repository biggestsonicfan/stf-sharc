// ==============================================================================
// OFFICIAL SOURCE LABELS
//
// Every dispatch handler below is tagged with its real name from the Sega
// Model 2 COP library source -- the 136 Fn_* symbols recovered from a shipped
// symbol table.  These are the actual source-code labels, not inferred names.
// They map 1:1 onto the 136-entry dispatch table at DM[0x30000]:
// 136 names, 136 slots, no leftovers on either side.
//
// The symbol table is not stored in dispatch order.  Two rules recover it:
//   1. PAIR REVERSAL   -- names come in adjacent pairs holding two consecutive
//      dispatch indices (2k-1, 2k) in reversed order:
//        "Fn_pop_matrix, Fn_push_matrix" -> 0x02, 0x01
//        "Fn_sub, Fn_add"                -> 0x14, 0x13
//        "Fn_x_rot, Fn_scale"            -> 0x08, 0x07
//   2. HALF-BLOCK SWAP -- past name 7 the table runs in 16-name blocks whose
//      two 8-name halves are swapped:
//        names [16k+7 .. 16k+14]  <-> indices [16k+0x0F .. 16k+0x16]
//        names [16k+15 .. 16k+22] <-> indices [16k+0x07 .. 16k+0x0E]
//      Name 0 is index 0x00 and name 135 is index 0x87, the two odd ones out.
//
// The recovered assignment is corroborated by the firmware itself throughout,
// e.g. Fn_initialize resets the bone-stack depth/pointer; Fn_get_x/y/z_axis
// read rot col0/col1/col2; Fn_put_c/get_c/add_c/sub_c/mul_c/div_c are exactly
// the six DM[0x30400] accumulator ops at 0x1B..0x20; Fn_ken2..ken5 and
// Fn_x_rot_e/y_rot_e/z_rot_e/trans_e each land on four consecutive rts stubs;
// Fn_parts_oidasi is the routine IDA names epc_oidasi.
//
// The opcode word for dispatch index N is always N * 0x00800101.
// Regenerate with annotate_official.py.
// ==============================================================================

// ==============================================================================
// cpres1_ad.asm -- SHARC (ADSP-21062) Coprocessor Firmware  [annotated]
// Sega Model 2 Board
//
// DISPATCH TABLE ENCODING
//   Command word: bits[30:23] == bits[15:8] == bits[7:0] = table index N
//   Handler address = DM[0x30000 + N]
//   Valid indices 0x00..0x87 = explicit handlers; 0x88..0xFF = error halt
//
// BONE SLOT LAYOUT  DM[i7], 12 floats, column-major 3x3 + translation
//   [0..2]  col0   [3..5] col1   [6..8] col2   [9..11] T[0..2]
//
// BONE STACK
//   DM[0x3033f] = i7 pointer (current slot, 12 words each)
//   DM[0x3033c] = depth (0..7); base = DM[0x305A0]
//
// PERMANENT DAG CONSTANTS (set at init)
//   i0=0x400000 (input FIFO)  i1=0xC00000 (output FIFO)
//   i2=0x30000 (dispatch table)  i3=0x30300 (scratch frame)
//   m0=0  m1=+1  m2=+2  m3=-3  m4=-8  m5=-11
//   m8=0 (indirect call)  m9=+1 (PM)  m13=-3 (PM)
//   All L regs = 0 (no circular buffering)
//
// INPUT FIFO   read: r0=dm(m0,i0) after polling flag0_in
// OUTPUT FIFO  write: dm(m0,i1)=r0 after polling flag1_in
// PM SCRATCH   PM[0x21F00..0x21F18]: temp matrix buffer
//              PM[0x21F18]: dummy sync write (1-cycle pipeline stall)
// ==============================================================================

.SECTION/PM seg_pmcode;

// ==============================================================================
// INTERRUPT / RESET VECTOR TABLE  PM 0x20000..0x2007F
// 4 words per vector.  Only the reset vector (offset 0) is live;
// all others are filled with rti.  Interrupts are never enabled.
// ==============================================================================
.SECTION/PM seg_pmcode;

    nop;
    nop;
    nop;
    nop;
    nop;
    jump _L20080 (db);
    nop;
    nop;
    nop;
    nop;
    nop;
    nop;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    nop;
    nop;
    nop;
    nop;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;
    rti;

// ==============================================================================
// _L20080  RESET / INIT  (PM 0x20080)
// Entry point after hardware reset. Establishes all DAG register constants,
// clears PM scratch and DM work areas, loads FP polynomial constants,
// builds the dispatch table at DM[0x30000], then falls into the command loop.
// ==============================================================================
_L20080:
    mode1=0x18000;
    mode2=0x60000;
    l0=0;
    l1=0;
    l2=0;
    l3=0;
    l4=0;
    l5=0;
    l6=0;
    l7=0;
    l8=0;
    l9=0;
    l10=0;
    l11=0;
    l12=0;
    l13=0;
    l14=0;
    l15=0;
    i0=0;
    m0=0x2;
    dm(i0,m0)=0xa100;
    dm(i0,m0)=0xca400;
    bit clr astat 0x600000;
    m0=0;
    m1=0x1;
    m2=0x2;
    m3=-3;
    m4=-8;
    m5=-11;
    m8=0;
    m9=0x1;
    m10=0x2;
    m11=-3;
    m12=-8;
    m13=-11;
    i0=0x400000;
    i1=0xc00000;
    call _L20367;
    i2=0x30000;
    dm(i2,m1)=0x20360;  /* [0x00] Fn_initialize               opcode 0x00000000  in=0  out=0   reset bone stack: depth DM[0x3033C]=0, current-slot ptr DM[0x3033F]=0x305A0 */
    dm(i2,m1)=0x20375;  /* [0x01] Fn_push_matrix              opcode 0x00800101  in=0  out=0   copy current bone frame to next stack slot, depth++ */
    dm(i2,m1)=0x20389;  /* [0x02] Fn_pop_matrix               opcode 0x01000202  in=0  out=0   restore previous bone frame, depth-- */
    dm(i2,m1)=0x2039b;  /* [0x03] Fn_base_matrix              opcode 0x01800303  in=0  out=0   current matrix = identity: rot=I, T=(0,0,0) */
    dm(i2,m1)=0x203aa;  /* [0x04] Fn_load_matrix              opcode 0x02000404  in=12 out=0   12 floats FIFO -> current matrix (3x3 cols + T) */
    dm(i2,m1)=0x203b3;  /* [0x05] Fn_get_matrix               opcode 0x02800505  in=0  out=12  current matrix (12 floats) -> FIFO */
    dm(i2,m1)=0x203bb;  /* [0x06] Fn_trans                    opcode 0x03000606  in=3  out=0   T += rot * (x,y,z)  -- translate along the local axes */
    dm(i2,m1)=0x203c3;  /* [0x07] Fn_scale                    opcode 0x03800707  in=3  out=0   rot[col][row] *= args[col] for all rows  -- scale the local axes */
    dm(i2,m1)=0x203cc;  /* [0x08] Fn_x_rot                    opcode 0x04000808  in=1  out=0   post-multiply rot by Rx(angle): col1=c*col1-s*col2, col2=s*col1+c*col2 */
    dm(i2,m1)=0x203d1;  /* [0x09] Fn_y_rot                    opcode 0x04800909  in=1  out=0   post-multiply rot by Ry(angle): col0=c*col0+s*col2, col2=-s*col0+c*col2; snapshots T->world_pos */
    dm(i2,m1)=0x203d6;  /* [0x0a] Fn_z_rot                    opcode 0x05000A0A  in=1  out=0   post-multiply rot by Rz(angle): col0=c*col0-s*col1, col1=s*col0+c*col1 */
    dm(i2,m1)=0x203e9;  /* [0x0b] Fn_mul_matrix               opcode 0x05800B0B  in=12 out=0   12 floats FIFO = M; current = M * current  (_L201E9) */
    dm(i2,m1)=0x2041f;  /* [0x0c] Fn_inv_matrix               opcode 0x06000C0C  in=0  out=0   invert the current matrix in place (_L2023D via DM scratch 0x30303) */
    dm(i2,m1)=0x2042a;  /* [0x0d] Fn_base_point               opcode 0x06800D0D  in=0  out=0   T[0..2] = 0 */
    dm(i2,m1)=0x20433;  /* [0x0e] Fn_load_point               opcode 0x07000E0E  in=3  out=0   3 floats FIFO -> T[0..2]  (i7 post-modified by 9 to reach T) */
    dm(i2,m1)=0x2043d;  /* [0x0f] Fn_get_point                opcode 0x07800F0F  in=0  out=3   T[0..2] -> FIFO */
    dm(i2,m1)=0x20460;  /* [0x10] Fn_base_3x3                 opcode 0x08001010  in=0  out=0   rot = identity 3x3 (T left untouched) */
    dm(i2,m1)=0x2047e;  /* [0x11] Fn_load_3x3                 opcode 0x08801111  in=9  out=0   9 floats FIFO -> rot (col0,col1,col2) */
    dm(i2,m1)=0x20496;  /* [0x12] Fn_get_3x3                  opcode 0x09001212  in=0  out=9   rot (9 floats) -> FIFO */
    dm(i2,m1)=0x205b0;  /* [0x13] Fn_add                      opcode 0x09801313  in=2  out=1   (a + b) -> float */
    dm(i2,m1)=0x205b8;  /* [0x14] Fn_sub                      opcode 0x0A001414  in=2  out=1   (a - b) -> float */
    dm(i2,m1)=0x205c0;  /* [0x15] Fn_mul                      opcode 0x0A801515  in=2  out=1   (a * b) -> float */
    dm(i2,m1)=0x205c8;  /* [0x16] Fn_div                      opcode 0x0B001616  in=2  out=1   (a / b) -> float */
    dm(i2,m1)=0x205d8;  /* [0x17] Fn_cvtws                    opcode 0x0B801717  in=1  out=1   int -> float */
    dm(i2,m1)=0x205de;  /* [0x18] Fn_cvtsw                    opcode 0x0C001818  in=1  out=1   float -> int (truncate) */
    dm(i2,m1)=0x205e4;  /* [0x19] Fn_sqr_r                    opcode 0x0C801919  in=1  out=1   1/sqrt(a): rsqrts seed + 3 Newton iterations (_L2029B) */
    dm(i2,m1)=0x205ea;  /* [0x1a] Fn_sqr                      opcode 0x0D001A1A  in=1  out=1   sqrt(a)  (_L202AE) */
    dm(i2,m1)=0x205f0;  /* [0x1b] Fn_put_c                    opcode 0x0D801B1B  in=1  out=0   C = arg          -- C is the scalar accumulator at DM[0x30400] */
    dm(i2,m1)=0x205f4;  /* [0x1c] Fn_get_c                    opcode 0x0E001C1C  in=0  out=1   C -> FIFO */
    dm(i2,m1)=0x205f8;  /* [0x1d] Fn_add_c                    opcode 0x0E801D1D  in=1  out=0   C = C + arg */
    dm(i2,m1)=0x205fe;  /* [0x1e] Fn_sub_c                    opcode 0x0F001E1E  in=1  out=0   C = C - arg */
    dm(i2,m1)=0x20604;  /* [0x1f] Fn_mul_c                    opcode 0x0F801F1F  in=1  out=0   C = C * arg */
    dm(i2,m1)=0x2060a;  /* [0x20] Fn_div_c                    opcode 0x10002020  in=1  out=0   C = C / arg  (_L205D0) */
    dm(i2,m1)=0x20610;  /* [0x21] Fn_sin                      opcode 0x10802121  in=1  out=1   sin(i16 angle) -> float */
    dm(i2,m1)=0x20616;  /* [0x22] Fn_cos                      opcode 0x11002222  in=1  out=1   cos(i16 angle) -> float */
    dm(i2,m1)=0x2061c;  /* [0x23] Fn_tan                      opcode 0x11802323  in=1  out=1   tan(i16 angle) -> float */
    dm(i2,m1)=0x20624;  /* [0x24] Fn_sinx                     opcode 0x12002424  in=2  out=1   sin(i16 angle) * scale -> float */
    dm(i2,m1)=0x2062d;  /* [0x25] Fn_cosx                     opcode 0x12802525  in=2  out=1   cos(i16 angle) * scale -> float */
    dm(i2,m1)=0x20636;  /* [0x26] Fn_asin                     opcode 0x13002626  in=1  out=1   asin(a) -> i16 angle  (_L20332) */
    dm(i2,m1)=0x2063c;  /* [0x27] Fn_atan                     opcode 0x13802727  in=2  out=1   atan2(y, x) -> i16 angle */
    dm(i2,m1)=0x20644;  /* [0x28] Fn_tri_shin                 opcode 0x14002828  in=3  out=3   triangle solve (law of cosines): 3 sides -> 2 i16 angles + 1 float */
    dm(i2,m1)=0x2066a;  /* [0x29] Fn_point_trans              opcode 0x14802929  in=3  out=3   local -> world: rot*(x,y,z) + T */
    dm(i2,m1)=0x20679;  /* [0x2a] Fn_get_inner                opcode 0x15002A2A  in=6  out=1   3D dot product; args interleaved (a.x,b.x,a.y,b.y,a.z,b.z) */
    dm(i2,m1)=0x2069a;  /* [0x2b] Fn_get_2d_r                 opcode 0x15802B2B  in=4  out=1   distance between two points in XZ */
    dm(i2,m1)=0x206ab;  /* [0x2c] Fn_get_3d_r                 opcode 0x16002C2C  in=6  out=1   distance between two 3D points */
    dm(i2,m1)=0x206c3;  /* [0x2d] Fn_get_2d_len               opcode 0x16802D2D  in=2  out=1   sqrt(a^2 + b^2) */
    dm(i2,m1)=0x206cb;  /* [0x2e] Fn_get_3d_len               opcode 0x17002E2E  in=3  out=1   sqrt(x^2 + y^2 + z^2)  (_L2034C) */
    dm(i2,m1)=0x206d5;  /* [0x2f] Fn_get_2d_dir               opcode 0x17802F2F  in=4  out=1   atan2(z2-z1, x2-x1) -> i16 angle */
    dm(i2,m1)=0x206e3;  /* [0x30] Fn_regular_vector           opcode 0x18003030  in=3  out=3   normalise a 3D vector: v * 1/|v|  (_L20356) */
    dm(i2,m1)=0x210da;  /* [0x31] Fn_fcurve_lin               opcode 0x18803131  in=4  out=1   linear key interpolation: a + (b-a)*t/span */
    dm(i2,m1)=0x210e9;  /* [0x32] Fn_fcurve_spl               opcode 0x19003232  in=6  out=1   Hermite cubic spline key interpolation */
    dm(i2,m1)=0x208e0;  /* [0x33] Fn_coli_dist                opcode 0x19803333  in=0  out=0   STUB in this revision (bare rts at PM 0x208E0, shared with Fn_coli_sink) */
    dm(i2,m1)=0x2049e;  /* [0x34] Fn_mov_matrix               opcode 0x1A003434  in=1  out=1   copy current matrix (12w) to DM[0x1400000 + arg/4]; outputs 0 */
    dm(i2,m1)=0x204ae;  /* [0x35] Fn_st_unit_mat              opcode 0x1A803535  in=2  out=0   current matrix -> unit-matrix cache[player][slot] */
    dm(i2,m1)=0x204c2;  /* [0x36] Fn_ld_unit_mat              opcode 0x1B003636  in=2  out=0   unit-matrix cache[player][slot] -> current matrix */
    dm(i2,m1)=0x204d6;  /* [0x37] Fn_mul_unit_mat             opcode 0x1B803737  in=2  out=0   current = cache[player][slot] * current */
    dm(i2,m1)=0x20da8;  /* [0x38] Fn_coli_set_ball_adrs       opcode 0x1C003838  in=1  out=0   point the collision engine at a sphere ("ball") table */
    dm(i2,m1)=0x20dc2;  /* [0x39] Fn_coli_point_trans         opcode 0x1C803939  in=4  out=0   collision-space point transform */
    dm(i2,m1)=0x20ddf;  /* [0x3a] Fn_area_table_gen           opcode 0x1D003A3A  in=4  out=0   build the area table */
    dm(i2,m1)=0x20ed5;  /* [0x3b] Fn_calc_coli_flag           opcode 0x1D803B3B  in=7  out=0   compute collision flags */
    dm(i2,m1)=0x208e0;  /* [0x3c] Fn_coli_sink                opcode 0x1E003C3C  in=0  out=0   STUB in this revision (bare rts at PM 0x208E0, shared with Fn_coli_dist) */
    dm(i2,m1)=0x204f2;  /* [0x3d] Fn_coli_trans_mat           opcode 0x1E803D3D  in=6  out=0   collision-space matrix transform */
    dm(i2,m1)=0x210b2;  /* [0x3e] Fn_coli_trans_xz            opcode 0x1F003E3E  in=5  out=0   collision-space XZ transform */
    dm(i2,m1)=0x203db;  /* [0x3f] Fn_zyx_rot                  opcode 0x1F803F3F  in=3  out=1   3 i16 angles -> x_rot, y_rot, z_rot applied in sequence */
    dm(i2,m1)=0x20515;  /* [0x40] Fn_calc_unit                opcode 0x20004040  in=0  out=0   STUB in this revision (bare rts at PM 0x20515) */
    dm(i2,m1)=0x20516;  /* [0x41] Fn_kage_leave_x_axis        opcode 0x20804141  in=?  out=?   reorient the matrix keeping the X axis (shadow/kage helper) */
    dm(i2,m1)=0x20529;  /* [0x42] Fn_kage_leave_z_axis        opcode 0x21004242  in=?  out=?   reorient the matrix keeping the Z axis (shadow/kage helper) */
    dm(i2,m1)=0x2053c;  /* [0x43] Fn_get_matrix_inner         opcode 0x21804343  in=1  out=0   current matrix (12w) -> inner bank PM[0x21F20 + 12*n] */
    dm(i2,m1)=0x2054c;  /* [0x44] Fn_load_matrix_inner        opcode 0x22004444  in=1  out=0   inner bank PM[0x21F20 + 12*n] -> current matrix */
    dm(i2,m1)=0x2055c;  /* [0x45] Fn_mul_matrix_inner         opcode 0x22804545  in=1  out=0   current = inner[n] * current  (_L201EA) */
    dm(i2,m1)=0x2056e;  /* [0x46] Fn_mul_matrix_inner_rev     opcode 0x23004646  in=1  out=0   current = current * inner[n] */
    dm(i2,m1)=0x2057a;  /* [0x47] Fn_mul_matrix_rev           opcode 0x23804747  in=12 out=0   12 floats FIFO = M; current = current * M  (_L2021E) */
    dm(i2,m1)=0x20585;  /* [0x48] Fn_read_ram                 opcode 0x24004848  in=1  out=1   DM[arg] -> FIFO */
    dm(i2,m1)=0x2058d;  /* [0x49] Fn_write_ram                opcode 0x24804949  in=2  out=0   DM[arg0] = arg1 */
    dm(i2,m1)=0x2076e;  /* [0x4a] Fn_osage                    opcode 0x25004A4A  in=1  out=0   "osage" dangling/cloth sim: streaming typed-block data reader */
    dm(i2,m1)=0x208df;  /* [0x4b] Fn_ken2                     opcode 0x25804B4B  in=0  out=0   STUB in this revision (bare rts at PM 0x208DF) */
    dm(i2,m1)=0x208df;  /* [0x4c] Fn_ken3                     opcode 0x26004C4C  in=0  out=0   STUB in this revision (bare rts at PM 0x208DF) */
    dm(i2,m1)=0x208df;  /* [0x4d] Fn_ken4                     opcode 0x26804D4D  in=0  out=0   STUB in this revision (bare rts at PM 0x208DF) */
    dm(i2,m1)=0x208df;  /* [0x4e] Fn_ken5                     opcode 0x27004E4E  in=0  out=0   STUB in this revision (bare rts at PM 0x208DF) */
    dm(i2,m1)=0x21120;  /* [0x4f] Fn_base_zy                  opcode 0x27804F4F  in=0  out=0   STUB in this revision (bare rts at PM 0x21120) */
    dm(i2,m1)=0x21120;  /* [0x50] Fn_base_yz                  opcode 0x28005050  in=0  out=0   STUB in this revision (bare rts at PM 0x21120) */
    dm(i2,m1)=0x2114f;  /* [0x51] Fn_get_glo_ang              opcode 0x28805151  in=0  out=3   extract the global Euler angles from the current matrix */
    dm(i2,m1)=0x21120;  /* [0x52] Fn_base_zyx_ang             opcode 0x29005252  in=0  out=0   STUB in this revision (bare rts at PM 0x21120) */
    dm(i2,m1)=0x21120;  /* [0x53] Fn_base_zyx                 opcode 0x29805353  in=0  out=0   STUB in this revision (bare rts at PM 0x21120) */
    dm(i2,m1)=0x21121;  /* [0x54] Fn_get_sm_ang_f             opcode 0x2A005454  in=9  out=3   "smooth angle" forward: identity + 9 ang ops, then extract 3 i16 Euler angles */
    dm(i2,m1)=0x2115f;  /* [0x55] Fn_get_sm_ang_r             opcode 0x2A805555  in=0  out=0   "smooth angle" reverse  (MAME-observed: 0 in, 0 out) */
    dm(i2,m1)=0x20446;  /* [0x56] Fn_get_x_axis               opcode 0x2B005656  in=0  out=3   rot col0 (offsets 0..2) -> 3 floats */
    dm(i2,m1)=0x2044e;  /* [0x57] Fn_get_y_axis               opcode 0x2B805757  in=0  out=3   rot col1 (offsets 3..5) -> 3 floats */
    dm(i2,m1)=0x20457;  /* [0x58] Fn_get_z_axis               opcode 0x2C005858  in=0  out=3   rot col2 (offsets 6..8) -> 3 floats */
    dm(i2,m1)=0x2068c;  /* [0x59] Fn_get_inner_2d             opcode 0x2C805959  in=4  out=1   2D dot product: a*b + c*d */
    dm(i2,m1)=0x206f4;  /* [0x5a] Fn_regular_vector_2d        opcode 0x2D005A5A  in=2  out=2   normalise a 2D vector: v * 1/|v|  (_L2035C) */
    dm(i2,m1)=0x20700;  /* [0x5b] Fn_rot_2d                   opcode 0x2D805B5B  in=3  out=2   rotate (x,y) by an i16 angle -> (x*cos - y*sin, y*cos + x*sin) */
    dm(i2,m1)=0x20711;  /* [0x5c] Fn_add3                     opcode 0x2E005C5C  in=6  out=3   vector add: (a0+a1, a2+a3, a4+a5) */
    dm(i2,m1)=0x20727;  /* [0x5d] Fn_sub3                     opcode 0x2E805D5D  in=6  out=3   vector subtract: (a0-a1, a2-a3, a4-a5) */
    dm(i2,m1)=0x2073d;  /* [0x5e] Fn_mul3                     opcode 0x2F005E5E  in=4  out=3   scalar * vector: (s*x, s*y, s*z) */
    dm(i2,m1)=0x2074f;  /* [0x5f] Fn_div3                     opcode 0x2F805F5F  in=0  out=0   STUB in this revision (bare rts at PM 0x2074F) */
    dm(i2,m1)=0x21120;  /* [0x60] Fn_calc_unit_2              opcode 0x30006060  in=0  out=0   STUB in this revision (bare rts at PM 0x21120) */
    dm(i2,m1)=0x21120;  /* [0x61] Fn_calc_unit_1              opcode 0x30806161  in=0  out=0   STUB in this revision (bare rts at PM 0x21120) */
    dm(i2,m1)=0x211e1;  /* [0x62] Fn_calc_unit_hara           opcode 0x31006262  in=9  out=0   "hara" (torso) unit-matrix solve */
    dm(i2,m1)=0x21209;  /* [0x63] Fn_get_loc_pos              opcode 0x31806363  in=7  out=3   world -> local position about a reference point + Y angle: [(E-A)cosD+(G-C)sinD, F-B, (G-C)cosD-(E-A)sinD] */
    dm(i2,m1)=0x208df;  /* [0x64] Fn_2d_coli_put              opcode 0x32006464  in=0  out=0   STUB in this revision (bare rts at PM 0x208DF) */
    dm(i2,m1)=0x208df;  /* [0x65] Fn_2d_coli_coli             opcode 0x32806565  in=0  out=0   STUB in this revision (bare rts at PM 0x208DF) */
    dm(i2,m1)=0x208df;  /* [0x66] Fn_2d_coli_get              opcode 0x33006666  in=0  out=0   STUB in this revision (bare rts at PM 0x208DF) */
    dm(i2,m1)=0x20597;  /* [0x67] Fn_st_glb_mat               opcode 0x33806767  in=1  out=0   store the current matrix into global matrix slot n */
    dm(i2,m1)=0x205a3;  /* [0x68] Fn_ld_glb_mat               opcode 0x34006868  in=1  out=0   load the current matrix from global matrix slot n */
    dm(i2,m1)=0x21237;  /* [0x69] Fn_mul_mot_yrot             opcode 0x34806969  in=?  out=?   multiply by the motion Y rotation (axis-angle matrix build, _L211C0) */
    dm(i2,m1)=0x20750;  /* [0x6a] Fn_glo_to_loc               opcode 0x35006A6A  in=3  out=3   world -> local: rot^T * (v - T) */
    dm(i2,m1)=0x2126b;  /* [0x6b] Fn_calc_unit_2_fast         opcode 0x35806B6B  in=17 out=1   2-bone IK solve (STF: calc_rob_angle_cont) */
    dm(i2,m1)=0x205af;  /* [0x6c] Fn_x_rot_e                  opcode 0x36006C6C  in=0  out=0   STUB in this revision (bare rts at PM 0x205AF) */
    dm(i2,m1)=0x205af;  /* [0x6d] Fn_y_rot_e                  opcode 0x36806D6D  in=0  out=0   STUB in this revision (bare rts at PM 0x205AF) */
    dm(i2,m1)=0x205af;  /* [0x6e] Fn_z_rot_e                  opcode 0x37006E6E  in=0  out=0   STUB in this revision (bare rts at PM 0x205AF) */
    dm(i2,m1)=0x205af;  /* [0x6f] Fn_trans_e                  opcode 0x37806F6F  in=0  out=0   STUB in this revision (bare rts at PM 0x205AF) */
    dm(i2,m1)=0x20bbe;  /* [0x70] Fn_area_coli                opcode 0x38007070  in=1  out=0   area collision test */
    dm(i2,m1)=0x20d8e;  /* [0x71] Fn_ball_to_unit             opcode 0x38807171  in=?  out=?   convert a collision ball into the unit-matrix frame */
    dm(i2,m1)=0x20d6f;  /* [0x72] Fn_outside_ball             opcode 0x39007272  in=3  out=0   outside-of-ball test */
    dm(i2,m1)=0x20d1f;  /* [0x73] Fn_kage_mat                 opcode 0x39807373  in=2  out=0   shadow ("kage") matrix */
    dm(i2,m1)=0x20d0a;  /* [0x74] Fn_kage_poly                opcode 0x3A007474  in=5  out=0   shadow ("kage") polygon */
    dm(i2,m1)=0x20cbf;  /* [0x75] Fn_kage_flag                opcode 0x3A807575  in=6  out=0   shadow ("kage") flags */
    dm(i2,m1)=0x2113f;  /* [0x76] Fn_get_glo_ang_zyx          opcode 0x3B007676  in=?  out=?   global Euler angles in ZYX order */
    dm(i2,m1)=0x20b1f;  /* [0x77] Fn_parts_oidasi             opcode 0x3B807777  in=4  out=9   part push-out ("oidasi") collision resolve; [0..1] = position correction deltas */
    dm(i2,m1)=0x20af1;  /* [0x78] Fn_put_poly                 opcode 0x3C007878  in=8  out=2   submit a polygon to the GEO display list */
    dm(i2,m1)=0x20abb;  /* [0x79] Fn_ziku_rot                 opcode 0x3C807979  in=?  out=?   rotate about an arbitrary axis ("ziku" = axis) */
    dm(i2,m1)=0x2040c;  /* [0x7a] Fn_mul_matrix3              opcode 0x3D007A7A  in=9  out=0   9 floats FIFO = 3x3 M; current = M * current  (_L20208) */
    dm(i2,m1)=0x20a8f;  /* [0x7b] Fn_scrn_clip                opcode 0x3D807B7B  in=?  out=?   screen clip test */
    dm(i2,m1)=0x2046c;  /* [0x7c] Fn_load_inner_3x3           opcode 0x3E007C7C  in=?  out=?   load the 3x3 from the inner bank */
    dm(i2,m1)=0x20487;  /* [0x7d] Fn_store_inner_3x3          opcode 0x3E807D7D  in=?  out=?   store the 3x3 to the inner bank */
    dm(i2,m1)=0x203fc;  /* [0x7e] Fn_mul_matrix_inner3        opcode 0x3F007E7E  in=2  out=0   3x3 from DM table 0x31000/0x31800 + index; current = M * current */
    dm(i2,m1)=0x20db3;  /* [0x7f] Fn_coli_copy_unit_matrix    opcode 0x3F807F7F  in=1  out=0   copy the unit matrix into the collision buffer */
    dm(i2,m1)=0x20961;  /* [0x80] Fn_zanzou_reserve           opcode 0x40008080  in=?  out=?   reserve an afterimage ("zanzou") slot */
    dm(i2,m1)=0x208e1;  /* [0x81] Fn_zanzou_init              opcode 0x40808181  in=0  out=0   afterimage ("zanzou") init */
    dm(i2,m1)=0x20911;  /* [0x82] Fn_zanzou_inc               opcode 0x41008282  in=0  out=1   afterimage ("zanzou") counter increment -> int */
    dm(i2,m1)=0x20937;  /* [0x83] Fn_zanzou_load_matrix_inner opcode 0x41808383  in=?  out=?   load an afterimage matrix from the inner bank */
    dm(i2,m1)=0x20926;  /* [0x84] Fn_zanzou_mul_matrix_inner  opcode 0x42008484  in=1  out=0   multiply an afterimage matrix from the inner bank */
    dm(i2,m1)=0x208e6;  /* [0x85] Fn_zanzou_get_info          opcode 0x42808585  in=1  out=0   read afterimage info */
    dm(i2,m1)=0x20955;  /* [0x86] Fn_zanzou_kill_timer_buffer opcode 0x43008686  in=1  out=0   kill the afterimage timer buffer */
    dm(i2,m1)=0x20946;  /* [0x87] Fn_zanzou_get_matrix_inner  opcode 0x43808787  in=?  out=?   get an afterimage matrix from the inner bank */
    lcntr=0x78, do (pc,0x1) until lce;
    dm(i2,m1)=0x2016f;
    i2=0x30000;
    i3=0x30300;
    i6=0x30300;
    dm(i6,m1)=0;
    dm(i6,m1)=0x3f800000;
    dm(i6,m1)=0x40000000;
    call _L20162;
    call _L20154;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    do (pc,0x18) until forever;
    r1=0xff;
    bit set astat 0x400000;
    do (pc,0x1) until not flag0_in;
    nop;
    bit clr astat 0x400000;
    r0=dm(m0,i0);
    r2=lshift r0 by -23;
    r2=r2 and r1;
    r3=r0 and r1;
    comp(r2,r3);
    if ne jump _L2016F (db,la);
    r4=lshift r0 by -8;
    r4=r4 and r1;
    comp(r2,r4);
    if ne jump _L2016F (la);
    dm(0x8)=r0;
    m7=r2;
    i15=dm(m7,i2);
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call (m8,i15);
    nop;

// ==============================================================================
// _L20154  LOAD_SIN_COS_CONSTANTS  (PM 0x20154)  called once at init
// Writes sin/cos polynomial coefficients to DM[0x30290..0x3029B].
// Includes pi/2 (0x3FC90FDA), pi (0x40490FDA), and Taylor-series terms.
// ==============================================================================
_L20154:
    i6=0x30290;
    dm(i6,m1)=0x3e8930a2;
    dm(i6,m1)=0x3fddb3d7;
    dm(i6,m1)=0x39800000;
    dm(i6,m1)=0xbf3853ad;
    dm(i6,m1)=0xbfb854a7;
    dm(i6,m1)=0x4098123b;
    dm(i6,m1)=0x408a3f7d;
    dm(i6,m1)=0;
    dm(i6,m1)=0x3f060a91;
    dm(i6,m1)=0x3fc90fda;
    rts (db);
    dm(i6,m1)=0x3f860a91;
    dm(i6,m1)=0x40490fda;

// ==============================================================================
// _L20162  LOAD_ATAN2_CONSTANTS  (PM 0x20162)  called once at init
// Writes atan2 minimax polynomial coefficients to DM[0x30284..0x3028D].
// DM[0x30284]=1/(2*pi), DM[0x30285]=2*pi, DM[0x30286..]=polynomial terms.
// ==============================================================================
_L20162:
    i6=0x30284;
    dm(i6,m1)=0x3ea2f983;
    dm(i6,m1)=0x40491000;
    dm(i6,m1)=0xb715777a;
    dm(i6,m1)=0x357fffff;
    dm(i6,m1)=0xab4f7738;
    dm(i6,m1)=0x2f3072aa;
    dm(i6,m1)=0xb2d731a5;
    dm(i6,m1)=0x3638ef1b;
    dm(i6,m1)=0xb9500d00;
    rts (db);
    dm(i6,m1)=0x3c088888;
    dm(i6,m1)=0xbe2aaaaa;

// ==============================================================================
// _L2016F  ERROR_HALT  (PM 0x2016F)
// Command validation failed (mismatched index bytes in command word).
// Sets ASTAT 0x200000, saves bad command to DM[9], spins forever.
// Also installed in dispatch table entries 0x88..0xFF as a catch-all.
// ==============================================================================
_L2016F:
    bit set astat 0x200000;
    dm(0x9)=r0;
    do (pc,0x1) until forever;
    nop;

// ==============================================================================
// _L20173  MAT_VEC_MUL  (PM 0x20173)  helper
// Multiply 3x3 bone rotation at DM[i7+0..8] by column vector (f0,f1,f2).
// Entry:  f0,f1,f2=vector; i7=bone slot (reads offsets 0..8)
// Exit:   f8=r8, f9=r9, f10=r10 = result.  Does NOT advance i7.
// ==============================================================================
_L20173:
    r8=dm(0x9,i7);
    r9=dm(0xa,i7);
    r10=dm(0xb,i7);
    r4=dm(0,i7);
    f12=f0*f4, r5=dm(0x1,i7);
    f13=f0*f5, f8=f8+f12, r6=dm(0x2,i7);
    f14=f0*f6, f9=f9+f13, r4=dm(0x3,i7);
    f12=f1*f4, f10=f10+f14, r5=dm(0x4,i7);
    f13=f1*f5, f8=f8+f12, r6=dm(0x5,i7);
    f14=f1*f6, f9=f9+f13, r4=dm(0x6,i7);
    f12=f2*f4, f10=f10+f14, r5=dm(0x7,i7);
    f13=f2*f5, f8=f8+f12, r6=dm(0x8,i7);
    rts (db);
    f14=f2*f6, f9=f9+f13;
    f10=f10+f14;

// ==============================================================================
// _L20182  MAT_VEC_MUL_STORE  (PM 0x20182)  helper
// Same multiply as _L20173, but ADDS result to r8/r9/r10 on entry
// and stores the sum back to DM[i7+9..11] (translation slots).
// Entry: i7=bone (loaded from DM[0x3033f]); r8/r9/r10=initial T accumulator
// ==============================================================================
_L20182:
    i7=dm(0x3033f);
    r8=dm(0x9,i7);
    r9=dm(0xa,i7);
    r10=dm(0xb,i7);
    r4=dm(0,i7);
    f12=f0*f4, r5=dm(0x1,i7);
    f13=f0*f5, f8=f8+f12, r6=dm(0x2,i7);
    f14=f0*f6, f9=f9+f13, r4=dm(0x3,i7);
    f12=f1*f4, f10=f10+f14, r5=dm(0x4,i7);
    f13=f1*f5, f8=f8+f12, r6=dm(0x5,i7);
    f14=f1*f6, f9=f9+f13, r4=dm(0x6,i7);
    f12=f2*f4, f10=f10+f14, r5=dm(0x7,i7);
    f13=f2*f5, f8=f8+f12, r6=dm(0x8,i7);
    f14=f2*f6, f9=f9+f13, dm(0x9,i7)=r8;
    f10=f10+f14, dm(0xa,i7)=r9;
    dm(0xb,i7)=r10;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L20195  SET_BONE_ROWS  (PM 0x20195)  helper
// Write the constant triple (r12,r13,r14) into all 9 rotation entries
// of the bone slot at i7 (stride 1, overwrites offsets 0..8).
// ==============================================================================
_L20195:
    r4=dm(0,i7);
    f12=f0*f4, r5=dm(0x1,i7);
    dm(0,i7)=r12;
    f13=f0*f5, r6=dm(0x2,i7);
    dm(0x1,i7)=r13;
    f14=f0*f6, r4=dm(0x3,i7);
    dm(0x2,i7)=r14;
    f12=f1*f4, r5=dm(0x4,i7);
    dm(0x3,i7)=r12;
    f13=f1*f5, r6=dm(0x5,i7);
    dm(0x4,i7)=r13;
    f14=f1*f6, r4=dm(0x6,i7);
    dm(0x5,i7)=r14;
    f12=f2*f4, r5=dm(0x7,i7);
    dm(0x6,i7)=r12;
    f13=f2*f5, r6=dm(0x8,i7);
    f14=f2*f6, dm(0x7,i7)=r13;
    dm(0x8,i7)=r14;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L201AA  ANG_X  (PM 0x201AA)  dispatch index 0x08  opcode 0x04000808
// Post-multiply running bone matrix by rotation about the X axis.
// Reads one 16-bit fixed-point angle from FIFO via _L202C1.
// Updates col1 (offsets 3..5) and col2 (offsets 6..8):
//   new_col1 = cos*col1 - sin*col2
//   new_col2 = sin*col1 + cos*col2
// Zero-angle exits early via _L20331 (identity, no cost).
// ==============================================================================
_L201AA:
    r0=r0 and r0;
    if eq jump _L20331;
    call _L202C1;
    r4=dm(0x3,i7);
    f8=f0*f4, r5=dm(0x6,i7);
    f12=f1*f5;
    f9=f1*f4, f8=f8-f12, r4=dm(0x4,i7);
    f13=f0*f5, dm(0x3,i7)=r8;
    f8=f0*f4, f9=f9+f13, r5=dm(0x7,i7);
    f12=f1*f5, dm(0x6,i7)=r9;
    f9=f1*f4, f8=f8-f12, r4=dm(0x5,i7);
    f13=f0*f5, dm(0x4,i7)=r8;
    f8=f0*f4, f9=f9+f13, r5=dm(0x8,i7);
    f12=f1*f5, dm(0x7,i7)=r9;
    f9=f1*f4, f8=f8-f12;
    f13=f0*f5, dm(0x5,i7)=r8;
    f9=f9+f13;
    dm(0x8,i7)=r9;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L201BF  ANG_Y  (PM 0x201BF)  dispatch index 0x09  opcode 0x04800909
// Post-multiply running bone matrix by rotation about the Y axis.
// Also snapshots T[] -> g_sharc.world_pos[] after updating the rotation.
// Falls into _L201C2 after the zero-angle check and cos/sin computation.
// Updates col2 (offsets 6..8) and col0 (offsets 0..2):
//   new_col2 = cos*col2 - sin*col0
//   new_col0 = sin*col2 + cos*col0
// ==============================================================================
_L201BF:
    r0=r0 and r0;
    if eq jump _L20331;
    call _L202C1;

// -- ANG_Y body: col2 (offsets 6..8) and col0 (offsets 0..2) --
// Also reached by direct call from compound ang handlers.
_L201C2:
    r4=dm(0x6,i7);
    f8=f0*f4, r5=dm(0,i7);
    f12=f1*f5;
    f9=f1*f4, f8=f8-f12, r4=dm(0x7,i7);
    f13=f0*f5, dm(0x6,i7)=r8;
    f8=f0*f4, f9=f9+f13, r5=dm(0x1,i7);
    f12=f1*f5, dm(0,i7)=r9;
    f9=f1*f4, f8=f8-f12, r4=dm(0x8,i7);
    f13=f0*f5, dm(0x7,i7)=r8;
    f8=f0*f4, f9=f9+f13, r5=dm(0x2,i7);
    f12=f1*f5, dm(0x1,i7)=r9;
    f9=f1*f4, f8=f8-f12;
    f13=f0*f5, dm(0x8,i7)=r8;
    f9=f9+f13;
    dm(0x2,i7)=r9;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L201D4  ANG_Z  (PM 0x201D4)  dispatch index 0x0A  opcode 0x05000A0A
// Post-multiply running bone matrix by rotation about the Z axis.
// Falls into _L201D7.
// Updates col0 (offsets 0..2) and col1 (offsets 3..5):
//   new_col0 = cos*col0 - sin*col1
//   new_col1 = sin*col0 + cos*col1
// ==============================================================================
_L201D4:
    r0=r0 and r0;
    if eq jump _L20331;
    call _L202C1;

// -- ANG_Z body: col0 (offsets 0..2) and col1 (offsets 3..5) --
// Also called directly by IK and set_ang_xyz compound handlers.
_L201D7:
    r4=dm(0,i7);
    f8=f0*f4, r5=dm(0x3,i7);
    f12=f1*f5;
    f9=f1*f4, f8=f8-f12, r4=dm(0x1,i7);
    f13=f0*f5, dm(0,i7)=r8;
    f8=f0*f4, f9=f9+f13, r5=dm(0x4,i7);
    f12=f1*f5, dm(0x3,i7)=r9;
    f9=f1*f4, f8=f8-f12, r4=dm(0x2,i7);
    f13=f0*f5, dm(0x1,i7)=r8;
    f8=f0*f4, f9=f9+f13, r5=dm(0x5,i7);
    f12=f1*f5, dm(0x4,i7)=r9;
    f9=f1*f4, f8=f8-f12;
    f13=f0*f5, dm(0x2,i7)=r8;
    f9=f9+f13;
    dm(0x5,i7)=r9;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L201E9  MAT_MUL_PM_BONE  (PM 0x201E9)  helper
// Multiply 3x4 matrix stored in PM[i8] (12 words) by the bone slot at DM[i7].
// Result (12 words) written to PM[i9].
// Used by load_bone_cache_mul and indexed-bone multiply handlers.
// ==============================================================================
_L201E9:
    i8=0x21f00;

// -- _L201EA: same as _L201E9 but i8=0x21F00 already set by caller --
_L201EA:
    r4=dm(i7,m1), r0=pm(i8,m9);
    f8=f0*f4, r5=dm(i7,m1);
    f9=f0*f5, r6=dm(i7,m1);
    lcntr=0x3, do (pc,0xb) until lce;
    f10=f0*f6, r4=dm(i7,m1), r1=pm(i8,m9);
    f12=f1*f4, r5=dm(i7,m1), r2=pm(i8,m9);
    f13=f1*f5, f8=f8+f12, r6=dm(i7,m1);
    f14=f1*f6, f9=f9+f13, r4=dm(i7,m1);
    f12=f2*f4, f10=f10+f14, r5=dm(i7,m1);
    f13=f2*f5, f8=f8+f12, r6=dm(i7,m4), r0=pm(i8,m9);
    f14=f2*f6, f9=f9+f13, r4=dm(i7,m1), pm(i9,m9)=r8;
    f8=f0*f4, f10=f10+f14, r5=dm(i7,m1), pm(i9,m9)=r9;
    f9=f0*f5, r6=dm(i7,m1), pm(i9,m9)=r10;
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    f10=f0*f6, r4=dm(i7,m1), r1=pm(i8,m9);
    f12=f1*f4, r5=dm(i7,m1), r2=pm(i8,m13);
    f13=f1*f5, f8=f8+f12, r6=dm(i7,m1);
    f14=f1*f6, f9=f9+f13, r4=dm(i7,m1);
    f12=f2*f4, f10=f10+f14, r5=dm(i7,m1);
    f13=f2*f5, f8=f8+f12, r6=dm(i7,m1);
    f14=f2*f6, f9=f9+f13, r12=dm(i7,m1);
    f10=f10+f14, r13=dm(i7,m1);
    f8=f8+f12, r14=dm(i7,m5);
    f9=f9+f13, pm(i9,m9)=r8;
    f10=f10+f14, pm(i9,m9)=r9;
    pm(i9,m13)=r10;
    rts (db);
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;

// ==============================================================================
// _L20208  MAT_MUL_PM_BONE_V2  (PM 0x20208)  helper
// Variant of _L201E9: multiply PM matrix at i8 by DM bone slot at i7.
// Used by load_and_mul_from_table (index 0x10/0x11).
// ==============================================================================
_L20208:
    i8=0x21f00;
    r4=dm(i7,m1), r0=pm(i8,m9);
    f8=f0*f4, r5=dm(i7,m1);
    f9=f0*f5, r6=dm(i7,m1);
    lcntr=0x3, do (pc,0xb) until lce;
    f10=f0*f6, r4=dm(i7,m1), r1=pm(i8,m9);
    f12=f1*f4, r5=dm(i7,m1), r2=pm(i8,m9);
    f13=f1*f5, f8=f8+f12, r6=dm(i7,m1);
    f14=f1*f6, f9=f9+f13, r4=dm(i7,m1);
    f12=f2*f4, f10=f10+f14, r5=dm(i7,m1);
    f13=f2*f5, f8=f8+f12, r6=dm(i7,m4), r0=pm(i8,m9);
    f14=f2*f6, f9=f9+f13, r4=dm(i7,m1), pm(i9,m9)=r8;
    f8=f0*f4, f10=f10+f14, r5=dm(i7,m1), pm(i9,m9)=r9;
    f9=f0*f5, r6=dm(i7,m1), pm(i9,m9)=r10;
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    r4=dm(i7,m3), r1=pm(i8,m9);
    r2=pm(i8,m13);
    r2=pm(i9,m9);
    rts (db);
    r2=pm(i9,m9);
    r2=pm(i9,m13);

// ==============================================================================
// _L2021E  MAT_MUL_DM_PM  (PM 0x2021E)  helper
// Multiply DM bone matrix at i7 (12 words) by PM matrix at i8 (12 words).
// Result written back in-place to DM[i7].
// ==============================================================================
_L2021E:
    i8=0x21f00;

// -- _L2021F: same as _L2021E but skips the i8=0x21F00 init --
_L2021F:
    r0=dm(i7,m1), r4=pm(i8,m9);
    f8=f0*f4, r5=pm(i8,m9);
    f9=f0*f5, r6=pm(i8,m9);
    lcntr=0x3, do (pc,0xb) until lce;
    f10=f0*f6, r1=dm(i7,m1), r4=pm(i8,m9);
    f12=f1*f4, r2=dm(i7,m1), r5=pm(i8,m9);
    f13=f1*f5, f8=f8+f12, r6=pm(i8,m9);
    f14=f1*f6, f9=f9+f13, r4=pm(i8,m9);
    f12=f2*f4, f10=f10+f14, r5=pm(i8,m9);
    f13=f2*f5, f8=f8+f12, r0=dm(i7,m3), r6=pm(i8,m12);
    f14=f2*f6, f9=f9+f13, dm(i7,m1)=r8, r4=pm(i8,m9);
    f8=f0*f4, f10=f10+f14, dm(i7,m1)=r9, r5=pm(i8,m9);
    f9=f0*f5, dm(i7,m2)=r10, r6=pm(i8,m9);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    f10=f0*f6, r1=dm(i7,m1), r4=pm(i8,m9);
    f12=f1*f4, r2=dm(i7,m1), r5=pm(i8,m9);
    f13=f1*f5, f8=f8+f12, r6=pm(i8,m9);
    f14=f1*f6, f9=f9+f13, r4=pm(i8,m9);
    f12=f2*f4, f10=f10+f14, r5=pm(i8,m9);
    f13=f2*f5, f8=f8+f12, r0=dm(i7,m3), r6=pm(i8,m9);
    f14=f2*f6, f9=f9+f13, r12=pm(i8,m9);
    f10=f10+f14, r13=pm(i8,m9);
    f8=f8+f12, r14=pm(i8,m13);
    f9=f9+f13, dm(i7,m1)=r8;
    f10=f10+f14, dm(i7,m1)=r9;
    dm(i7,m5)=r10;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L2023D  INVERT_TRANSPOSE_BONE  (PM 0x2023D)  helper
// Compute the inverse-transpose of the 3x3 rotation at i7.
// Implementation: 3x3 adjugate (cross-product matrix) / determinant.
// Determinant uses 3-iteration Newton-Raphson reciprocal.
// Also computes negated transformed translation to i6[9..11].
// Entry: i7=source bone, i6=dest buffer. Exit: i6 restored to 0x30303.
// ==============================================================================
_L2023D:
    r11=0;
    r6=dm(0x8,i7);
    r1=dm(0x4,i7);
    f8=f1*f6, r0=dm(0x3,i7);
    f14=f0*f6, r5=dm(0x7,i7);
    f9=f0*f5, r2=dm(0x5,i7);
    f12=f2*f5, r4=dm(0x6,i7);
    f10=f2*f4, f8=f8-f12, r6=dm(0x2,i7);
    dm(0,i6)=r8;
    f13=f1*f4, f10=f10-f14, r1=dm(0x7,i7);
    dm(0x3,i6)=r10;
    f8=f1*f6, f9=f9-f13, r0=dm(0x6,i7);
    dm(0x6,i6)=r9;
    f14=f0*f6, r5=dm(0x1,i7);
    f9=f0*f5, r2=dm(0x8,i7);
    f12=f2*f5, r4=dm(0,i7);
    f10=f2*f4, f8=f8-f12, r6=dm(0x5,i7);
    dm(0x1,i6)=r8;
    f13=f1*f4, f10=f10-f14, r1=dm(0x1,i7);
    dm(0x4,i6)=r10;
    f8=f1*f6, f9=f9-f13, r0=dm(0,i7);
    dm(0x7,i6)=r9;
    f14=f0*f6, r5=dm(0x4,i7);
    f9=f0*f5, r2=dm(0x2,i7);
    f12=f2*f5, r4=dm(0x3,i7);
    f10=f2*f4, f8=f8-f12, r6=dm(0xb,i7);
    dm(0x2,i6)=r8;
    f13=f1*f4, f10=f10-f14, r5=dm(0xa,i7);
    dm(0x5,i6)=r10;
    f9=f9-f13, r4=dm(0x9,i7);
    dm(0x8,i6)=r9;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0,i6);
    f8=f4*f0, r1=dm(0xa,i7);
    r5=dm(0x3,i6);
    f9=f1*f5, r2=dm(0xb,i7);
    r6=dm(0x6,i6);
    f10=f2*f6;
    f8=f8+f9;
    f8=f8+f10;
    f10=-f8;
    dm(0x9,i6)=r10;
    r4=dm(0x9,i7);
    r0=dm(0x1,i6);
    f8=f4*f0, r1=dm(0xa,i7);
    r5=dm(0x4,i6);
    f9=f1*f5, r2=dm(0xb,i7);
    r6=dm(0x7,i6);
    f10=f2*f6;
    f8=f8+f9;
    f8=f8+f10;
    f10=-f8;
    dm(0xa,i6)=r10;
    r4=dm(0x9,i7);
    r0=dm(0x2,i6);
    f8=f4*f0, r1=dm(0xa,i7);
    r5=dm(0x5,i6);
    f9=f1*f5, r2=dm(0xb,i7);
    r6=dm(0x8,i6);
    f10=f2*f6;
    f8=f8+f9;
    f8=f8+f10;
    f10=-f8;
    dm(0xb,i6)=r10;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r4=dm(0,i7);
    r0=dm(0,i6);
    f8=f4*f0, r1=dm(0x1,i7);
    r5=dm(0x3,i6);
    f9=f1*f5, r2=dm(0x2,i7);
    r6=dm(0x6,i6);
    f10=f2*f6;
    f8=f8+f9;
    f8=f8+f10;
    r1=0x3f800000;
    r2=r8;
    f3=recips f2, r4=r1;
    f12=f3*f2, r11=dm(m2,i3);
    f4=f3*f4, f3=f11-f12;
    f12=f3*f12;
    f4=f3*f4, f3=f11-f12;
    f12=f3*f12;
    f4=f3*f4, f3=f11-f12;
    f0=f3*f4;
    lcntr=0xc, do (pc,0x3) until lce;
    r4=dm(i6,m0);
    f4=f4*f0;
    dm(i6,m1)=r4;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    i6=0x30303;
    rts;

// ==============================================================================
// _L2029B  RSQRT  (PM 0x2029B)  helper
// 1/sqrt(f5) using SHARC rsqrts seed + 3 Newton-Raphson iterations.
// Entry: f5>=0. Exit: f4=1/sqrt(f5). Zero input -> _L202AC -> f4=0.
// ==============================================================================
_L2029B:
    r11=r5 and r5;
    if eq jump _L202AC;
    r11=0x40400000;
    r3=0x3f000000;
    f4=rsqrts f5;
    f12=f4*f4;
    f12=f5*f12;
    f4=f3*f4, f12=f11-f12;
    f4=f4*f12;
    f12=f4*f4;
    f12=f5*f12;
    f4=f3*f4, f12=f11-f12;
    f4=f4*f12;
    f12=f4*f4;
    rts (db), f12=f5*f12;
    f4=f3*f4, f12=f11-f12;
    f4=f4*f12;

// -- rsqrt zero-input: return f4=0 --
_L202AC:
    r4=0;
    rts;

// ==============================================================================
// _L202AE  SQRT  (PM 0x202AE)  helper
// sqrt(f0) using rsqrts seed + 3 Newton-Raphson iterations.
// Entry: f0>=0 (zero input returns immediately). Exit: f0=sqrt(input).
// ==============================================================================
_L202AE:
    r11=r0 and r0;
    if eq rts;
    r11=0x40400000;
    r2=0x3f000000;
    f4=rsqrts f0;
    f15=f4*f4;
    f15=f0*f15;
    f4=f2*f4, f15=f11-f15;
    f4=f4*f15;
    f15=f4*f4;
    f15=f0*f15;
    f4=f2*f4, f15=f11-f15;
    f4=f4*f15;
    f15=f4*f4;
    f15=f0*f15;
    f4=f2*f4, f15=f11-f15;
    rts (db);
    f4=f4*f15;
    f0=f0*f4;

// ==============================================================================
// _L202C1  ANGLE_TO_SINCOS  (PM 0x202C1)  helper
// Convert 16-bit fixed-point angle to (sin, cos) float pair via lookup table.
// Angle format: 0x0000=0 deg, 0x4000=90 deg, 0x10000=360 deg (wraps).
// Entry: r0=16-bit signed angle. Exit: r1=sin (float), r0=cos (float).
// Table at DM[0x1C10000] (external SRAM), cos stride +0x20000 from sin.
// ==============================================================================
_L202C1:
    r12=0x1c10000;
    m7=0x20000;
    r0=lshift r0 by 0x10;
    r0=ashift r0 by -16;
    r12=r12+r0;
    i6=r12;
    rts (db);
    r1=dm(m0,i6);
    r0=dm(m7,i6);

// ==============================================================================
// _L202CA  ATAN2_TO_FIXED  (PM 0x202CA)  helper
// atan2(y,x) returned as 16-bit fixed-point angle (0x10000 = 360 deg).
// Calls _L202D1 (float atan2) then scales by 2^15/pi.
// Entry: f0=x, f1=y. Exit: r0=i16 angle (sign-extended to 32 bits).
// ==============================================================================
_L202CA:
    call _L202D1;
    r1=0x4622f983;
    f0=f0*f1;
    r0=fix f0;
    rts (db);
    r0=lshift r0 by 0x10;
    r0=lshift r0 by -16;

// ==============================================================================
// _L202D1  ATAN2_FLOAT  (PM 0x202D1)  helper
// Full atan2(y,x) in float radians using minimax polynomial approximation.
// Range reduction, multiple octant handling, polynomial from DM[0x30290].
// Entry: r0=x (float), r1=y (float). Exit: f0=atan2 result in radians.
// ==============================================================================
_L202D1:
    dm(0x1e,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=r1;
    r1=dm(0x1e,i3);
    i6=0x30290;
    r11=0x40000000;
    r2=0;
    f1=pass f1;
    if eq jump _L2032F;
    if lt r2=dm(0xb,i6);
    r4=logb f0, r7=r0;
    r1=logb f1, r15=r1;
    r1=r4-r1;
    r4=0x7c;
    comp(r1,r4);
    if ge jump _L2032C;
    r4=-r4;
    comp(r1,r4);
    if le jump _L20329;
    f7=recips f15, r1=r7;
    f15=f7*f15;
    f1=f1*f7, f7=f11-f15;
    f15=f7*f15;
    f1=f1*f7, f7=f11-f15;
    f15=f7*f15;
    f1=f1*f7, f7=f11-f15;
    f0=f1*f7;
    f2=pass f2;
    if ne f0=-f0;
    r10=0;
    f15=abs f0;
    r7=0x3f800000;
    comp(f15,f7), r4=dm(0,i6);
    if le jump _L202FD;
    f7=recips f15, r1=r7;
    f15=f7*f15;
    f1=f1*f7, f7=f11-f15;
    f15=f7*f15;
    f1=f1*f7, f7=f11-f15;
    f15=f7*f15;
    f1=f1*f7, f7=f11-f15;
    f15=f1*f7;
    r10=0x2;

// -- atan2: secondary range reduction (|x| ~= |y|) --
_L202FD:
    comp(f15,f4);
    if lt jump _L2030B;
    r10=r10+1, r4=dm(0x1,i6);
    f14=f4*f15;
    f7=f14-f7;
    f15=f4+f15;
    f7=recips f15, r1=r7;
    f15=f7*f15;
    f1=f1*f7, f7=f11-f15;
    f15=f7*f15;
    f1=f1*f7, f7=f11-f15;
    f15=f7*f15;
    f1=f1*f7, f7=f11-f15;
    f15=f1*f7;

// -- atan2: minimax polynomial evaluation --
_L2030B:
    f7=abs f15, r4=dm(0x2,i6);
    comp(f7,f4);
    if le jump _L2031F;
    f1=f15*f15, r4=dm(0x3,i6);
    f7=f1*f4, r4=dm(0x4,i6);
    f7=f7+f4, r4=dm(0x5,i6);
    f7=f7*f1;
    f14=f1+f4, r4=dm(0x6,i6);
    f14=f14*f1;
    f14=f14+f4;
    f7=recips f14, r1=r7;
    f14=f7*f14;
    f1=f1*f7, f7=f11-f14;
    f14=f7*f14;
    f1=f1*f7, f7=f11-f14;
    f14=f7*f14;
    f1=f1*f7, f7=f11-f14;
    f7=f1*f7;
    f7=f7*f15;
    f15=f7+f15;

// -- atan2: reconstruct result + add octant offset --
_L2031F:
    r1=r10-1, r7=dm(i6,0x7);
    m7=r10;
    if gt f15=-f15;
    r4=dm(m7,i6);
    f15=f15+f4;

// -- atan2: apply y-sign flip to result --
_L20324:
    f2=pass f2;
    if ne f15=f2-f15;

// -- atan2: return (copy f15->f0, apply x-sign) --
_L20326:
    rts (db), f0=pass f0;
    if lt f15=-f15;
    f0=pass f15;

// -- atan2: |x| >> |y| degenerate: result = 0 --
_L20329:
    jump _L20324 (db);
    r15=0;
    nop;

// -- atan2: |y| >> |x| degenerate: result = +/-pi/2 --
_L2032C:
    jump _L20326 (db);
    r15=dm(0x9,i6);
    nop;

// -- atan2: x==0 special case --
_L2032F:
    f0=pass f0;
    if ne jump _L2032C;

// -- zero-angle early exit shared by ang_x/ang_y/ang_z --
_L20331:
    rts;

// ==============================================================================
// _L20332  ASIN_FIXED  (PM 0x20332)  helper
// asin(f1) as 16-bit fixed-point angle.
// Special cases: f1==+1.0->0x4000 (90 deg), f1==-1.0->0xC000 (-90 deg).
// ==============================================================================
_L20332:
    f15=f1*f1, r11=dm(m1,i3);
    comp(f11,f1);
    if eq jump _L2033B;
    f10=-f11;
    comp(f10,f1);
    if eq jump _L2033D;
    f0=f11-f15;
    call _L202AE;
    jump _L202CA;

// -- asin: f1==+1.0 -> return 0x4000 (90 deg) --
_L2033B:
    r0=0x4000;
    rts;

// -- asin: f1==-1.0 -> return 0xC000 (-90 deg) --
_L2033D:
    r0=0xc000;
    rts;

// ==============================================================================
// _L2033F  ACOS_FLOAT  (PM 0x2033F)  helper
// acos(f1) in float radians.
// Special cases: f1==+1.0->pi/2, f1==-1.0->-pi/2 (as float constants).
// ==============================================================================
_L2033F:
    f15=f1*f1, r11=dm(m1,i3);
    comp(f11,f1);
    if eq jump _L20348;
    f10=-f11;
    comp(f10,f1);
    if eq jump _L2034A;
    f0=f11-f15;
    call _L202AE;
    jump _L202D1;

// -- acos: f1==+1.0 -> 0x3FC90FD7 (pi/2) --
_L20348:
    r0=0x3fc90fd7;
    rts;

// -- acos: f1==-1.0 -> 0xBFC90FD7 (-pi/2) --
_L2034A:
    r0=0xbfc90fd7;
    rts;

// ==============================================================================
// _L2034C  VEC3_MAG  (PM 0x2034C)  helper
// Magnitude of 3D vector (f0,f1,f2). Exit: f0=sqrt(x^2+y^2+z^2).
// ==============================================================================
_L2034C:
    f11=f0*f0;
    f12=f1*f1;
    f13=f2*f2;
    jump _L202AE (db);
    f11=f11+f12;
    f0=f11+f13;

// ==============================================================================
// _L20352  VEC2_MAG  (PM 0x20352)  helper
// Magnitude of 2D vector (f0,f1). Exit: f0=sqrt(x^2+y^2).
// ==============================================================================
_L20352:
    f11=f0*f0;
    jump _L202AE (db);
    f12=f1*f1;
    f0=f11+f12;

// ==============================================================================
// _L20356  VEC3_NORMALIZE_INV  (PM 0x20356)  helper
// 1/|v| for 3D vector (f0,f1,f2). Exit: f4=1/magnitude.
// Caller multiplies each component by f4 to get unit vector.
// ==============================================================================
_L20356:
    f11=f0*f0;
    f12=f1*f1;
    f13=f2*f2;
    jump _L2029B (db);
    f11=f11+f12;
    f5=f11+f13;

// ==============================================================================
// _L2035C  VEC2_NORMALIZE_INV  (PM 0x2035C)  helper
// 1/|v| for 2D vector (f0,f1). Exit: f4=1/magnitude.
// ==============================================================================
_L2035C:
    f11=f0*f0;
    jump _L2029B (db);
    f12=f1*f1;
    f5=f11+f12;

// ----------------------------------------------------------------------------
// Fn_initialize                [official source label]   dispatch 0x00  opcode 0x00000000
//   in=0  out=0    PM 0x20360   reset bone stack: depth DM[0x3033C]=0, current-slot ptr DM[0x3033F]=0x305A0
// ----------------------------------------------------------------------------
    r0=0;
    dm(0x3033c)=r0;
    r0=0x305a0;
    dm(0x3033f)=r0;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L20367  MEM_CLEAR  (PM 0x20367)  called once at init
// Zero PM[0x21F00..0x21FFF] (256 words) and DM[0x30000..0x33FFF] (16384 words).
// Must complete before the dispatch table is written.
// ==============================================================================
_L20367:
    i8=0x21f00;
    r0=0;
    lcntr=0x100, do (pc,0x1) until lce;
    pm(i8,0x1)=r0;
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    nop;
    i7=0x30000;
    r0=0;
    lcntr=0x4000, do (pc,0x1) until lce;
    dm(i7,0x1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ==============================================================================
// _L20375  PUSH_BONE  (PM 0x20375)  dispatch index 0x01  opcode 0x00800101
// Push current bone frame: copy 11 words forward by stride 0xB into new slot.
// Increments DM[0x3033c] (stack depth). Max depth 7; drops push if at max.
// ==============================================================================

// ----------------------------------------------------------------------------
// Fn_push_matrix               [official source label]   dispatch 0x01  opcode 0x00800101
//   in=0  out=0    PM 0x20375   copy current bone frame to next stack slot, depth++
// ----------------------------------------------------------------------------
_L20375:
    r0=dm(0x3033c);
    r1=0x7;
    comp(r0,r1);
    if ge jump _L20386 (db);
    r0=r0+1;
    dm(0x3033c)=r0;
    i7=dm(0x3033f);
    m7=0xb;
    lcntr=0xb, do (pc,0x2) until lce;
    r0=dm(i7,m1);
    dm(m7,i7)=r0;
    r0=dm(i7,m1);
    dm(m7,i7)=r0;
    dm(0x3033f)=i7;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// -- push_bone: depth >= 7, stack full, return without pushing --
_L20386:
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L20389  POP_BONE  (PM 0x20389)  dispatch index 0x02  opcode 0x01000202
// Pop current bone frame: frame pointer -= 12, depth--.
// No-op if depth==0 (underflow) or depth>=8 (corrupted).
// ==============================================================================

// ----------------------------------------------------------------------------
// Fn_pop_matrix                [official source label]   dispatch 0x02  opcode 0x01000202
//   in=0  out=0    PM 0x20389   restore previous bone frame, depth--
// ----------------------------------------------------------------------------
_L20389:
    r0=dm(0x3033c);
    r0=pass r0;
    if eq rts;
    r1=0x8;
    comp(r0,r1);
    if ge jump _L20398 (db);
    r0=r0-1;
    dm(0x3033c)=r0;
    r0=dm(0x3033f);
    r1=0xc;
    r0=r0-r1;
    dm(0x3033f)=r0;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// -- pop_bone: depth out of valid range, return without popping --
_L20398:
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L2039B  SET_IDENTITY  (PM 0x2039B)  dispatch index 0x03  opcode 0x01800303
// Write identity rotation and zero translation to current bone slot (12 words):
//   [1,0,0, 0,1,0, 0,0,1, 0,0,0]
// ==============================================================================

// ----------------------------------------------------------------------------
// Fn_base_matrix               [official source label]   dispatch 0x03  opcode 0x01800303
//   in=0  out=0    PM 0x2039B   current matrix = identity: rot=I, T=(0,0,0)
// ----------------------------------------------------------------------------
_L2039B:
    i7=dm(0x3033f);
    r0=0;
    r1=0x3f800000;
    lcntr=0x2, do (pc,0x4) until lce;
    dm(i7,m1)=r1;
    dm(i7,m1)=r0;
    dm(i7,m1)=r0;
    dm(i7,m1)=r0;
    dm(i7,m1)=r1;
    dm(i7,m1)=r0;
    dm(i7,m1)=r0;
    dm(i7,m1)=r0;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ----------------------------------------------------------------------------
// Fn_load_matrix               [official source label]   dispatch 0x04  opcode 0x02000404
//   in=12 out=0    PM 0x203AA   12 floats FIFO -> current matrix (3x3 cols + T)
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x4) until lce;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    nop;
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_matrix                [official source label]   dispatch 0x05  opcode 0x02800505
//   in=0  out=12   PM 0x203B3   current matrix (12 floats) -> FIFO
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x5) until lce;
    r0=dm(i7,m1);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    nop;
    nop;
    rts;

// ==============================================================================
// _L203BB  SET_POS  (PM 0x203BB)  dispatch index 0x06  opcode 0x03000606
// Read (x,y,z) from FIFO, compute rot*(x,y,z), add to T[0..2].
// Calls _L20182 which reads existing T from slot[9..11] as accumulator.
// This is the "translate" command: T += R*v.
// ==============================================================================

// ----------------------------------------------------------------------------
// Fn_trans                     [official source label]   dispatch 0x06  opcode 0x03000606
//   in=3  out=0    PM 0x203BB   T += rot * (x,y,z)  -- translate along the local axes
// ----------------------------------------------------------------------------
_L203BB:
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    call _L20182;
    rts;

// ----------------------------------------------------------------------------
// Fn_scale                     [official source label]   dispatch 0x07  opcode 0x03800707
//   in=3  out=0    PM 0x203C3   rot[col][row] *= args[col] for all rows  -- scale the local axes
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);

// ==============================================================================
// _L203C9  APPLY_MAT_TO_SLOT  (PM 0x203C9)  helper
// Load i7=current bone, call _L20195 (write r0/r1/r2 triple to all 9 entries).
// ==============================================================================
_L203C9:
    i7=dm(0x3033f);
    call _L20195;
    rts;

// ----------------------------------------------------------------------------
// Fn_x_rot                     [official source label]   dispatch 0x08  opcode 0x04000808
//   in=1  out=0    PM 0x203CC   post-multiply rot by Rx(angle): col1=c*col1-s*col2, col2=s*col1+c*col2
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);

// ==============================================================================
// _L203CE  ANG_X_DISPATCH  (PM 0x203CE)  helper
// Read one angle from FIFO into r0, load i7, call ang_x (_L201AA).
// ==============================================================================
_L203CE:
    i7=dm(0x3033f);
    call _L201AA;
    rts;

// ----------------------------------------------------------------------------
// Fn_y_rot                     [official source label]   dispatch 0x09  opcode 0x04800909
//   in=1  out=0    PM 0x203D1   post-multiply rot by Ry(angle): col0=c*col0+s*col2, col2=-s*col0+c*col2; snapshots T->world_pos
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);

// ==============================================================================
// _L203D3  ANG_Y_DISPATCH  (PM 0x203D3)  helper
// Read one angle from FIFO into r0, load i7, call ang_y (_L201BF).
// ==============================================================================
_L203D3:
    i7=dm(0x3033f);
    call _L201BF;
    rts;

// ----------------------------------------------------------------------------
// Fn_z_rot                     [official source label]   dispatch 0x0A  opcode 0x05000A0A
//   in=1  out=0    PM 0x203D6   post-multiply rot by Rz(angle): col0=c*col0-s*col1, col1=s*col0+c*col1
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    i7=dm(0x3033f);
    call _L201D4;
    rts;

// ----------------------------------------------------------------------------
// Fn_zyx_rot                   [official source label]   dispatch 0x3F  opcode 0x1F803F3F
//   in=3  out=1    PM 0x203DB   3 i16 angles -> x_rot, y_rot, z_rot applied in sequence
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201D4;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201BF;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201AA;
    r0=0;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_mul_matrix                [official source label]   dispatch 0x0B  opcode 0x05800B0B
//   in=12 out=0    PM 0x203E9   12 floats FIFO = M; current = M * current  (_L201E9)
// ----------------------------------------------------------------------------
    i8=0x21f00;
    lcntr=0xc, do (pc,0x4) until lce;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    nop;
    pm(i8,m9)=r0;
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    i7=dm(0x3033f);
    i9=0x21f0c;
    call _L201E9;
    r0=pm(i9,m9);
    lcntr=0xa, do (pc,0x1) until lce;
    dm(i7,m1)=r0, r0=pm(i9,m9);
    dm(i7,m1)=r0, r0=pm(i9,m13);
    dm(i7,m5)=r0;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ----------------------------------------------------------------------------
// Fn_mul_matrix_inner3         [official source label]   dispatch 0x7E  opcode 0x3F007E7E
//   in=2  out=0    PM 0x203FC   3x3 from DM table 0x31000/0x31800 + index; current = M * current
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    r15=0x31000;
    r1=r1 and r1;
    if eq jump _L20404;
    r15=0x31800;

// -- load_and_mul_from_table/apply_external_rot: player != 0 branch --
_L20404:
    r15=r15+r0;
    i5=r15;
    i8=0x21f00;
    lcntr=0x9, do (pc,0x3) until lce;
    r0=dm(i5,m1);
    nop;
    pm(i8,m9)=r0;
    jump _L20412;

// ----------------------------------------------------------------------------
// Fn_mul_matrix3               [official source label]   dispatch 0x7A  opcode 0x3D007A7A
//   in=9  out=0    PM 0x2040C   9 floats FIFO = 3x3 M; current = M * current  (_L20208)
// ----------------------------------------------------------------------------
    i8=0x21f00;
    lcntr=0x9, do (pc,0x4) until lce;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    nop;
    pm(i8,m9)=r0;

// -- apply_external_rot: merge point, call _L20208 mat-mul --
_L20412:
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    i7=dm(0x3033f);
    i9=0x21f0c;
    call _L20208;
    r0=pm(i9,m9);
    lcntr=0x7, do (pc,0x1) until lce;
    dm(i7,m1)=r0, r0=pm(i9,m9);
    dm(i7,m1)=r0, r0=pm(i9,m12);
    dm(i7,m4)=r0;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ----------------------------------------------------------------------------
// Fn_inv_matrix                [official source label]   dispatch 0x0C  opcode 0x06000C0C
//   in=0  out=0    PM 0x2041F   invert the current matrix in place (_L2023D via DM scratch 0x30303)
// ----------------------------------------------------------------------------
    i6=0x30303;
    i7=dm(0x3033f);
    call _L2023D;
    lcntr=0xb, do (pc,0x2) until lce;
    r0=dm(i6,m1);
    dm(i7,m1)=r0;
    r0=dm(i6,m5);
    dm(i7,m5)=r0;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ----------------------------------------------------------------------------
// Fn_base_point                [official source label]   dispatch 0x0D  opcode 0x06800D0D
//   in=0  out=0    PM 0x2042A   T[0..2] = 0
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    r0=dm(i7,0x9);
    r0=0;
    dm(i7,m1)=r0;
    dm(i7,m1)=r0;
    dm(i7,m1)=r0;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ----------------------------------------------------------------------------
// Fn_load_point                [official source label]   dispatch 0x0E  opcode 0x07000E0E
//   in=3  out=0    PM 0x20433   3 floats FIFO -> T[0..2]  (i7 post-modified by 9 to reach T)
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    r0=dm(i7,0x9);
    lcntr=0x3, do (pc,0x4) until lce;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    nop;
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_point                 [official source label]   dispatch 0x0F  opcode 0x07800F0F
//   in=0  out=3    PM 0x2043D   T[0..2] -> FIFO
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    r0=dm(i7,0x9);
    lcntr=0x3, do (pc,0x5) until lce;
    r0=dm(i7,m1);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    nop;
    nop;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_x_axis                [official source label]   dispatch 0x56  opcode 0x2B005656
//   in=0  out=3    PM 0x20446   rot col0 (offsets 0..2) -> 3 floats
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    lcntr=0x3, do (pc,0x5) until lce;
    r0=dm(i7,m1);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    nop;
    nop;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_y_axis                [official source label]   dispatch 0x57  opcode 0x2B805757
//   in=0  out=3    PM 0x2044E   rot col1 (offsets 3..5) -> 3 floats
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    r0=dm(i7,0x3);
    lcntr=0x3, do (pc,0x5) until lce;
    r0=dm(i7,m1);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    nop;
    nop;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_z_axis                [official source label]   dispatch 0x58  opcode 0x2C005858
//   in=0  out=3    PM 0x20457   rot col2 (offsets 6..8) -> 3 floats
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    r0=dm(i7,0x6);
    lcntr=0x3, do (pc,0x5) until lce;
    r0=dm(i7,m1);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    nop;
    nop;
    rts;

// ----------------------------------------------------------------------------
// Fn_base_3x3                  [official source label]   dispatch 0x10  opcode 0x08001010
//   in=0  out=0    PM 0x20460   rot = identity 3x3 (T left untouched)
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    r0=0;
    r1=0x3f800000;
    lcntr=0x2, do (pc,0x4) until lce;
    dm(i7,m1)=r1;
    dm(i7,m1)=r0;
    dm(i7,m1)=r0;
    dm(i7,m1)=r0;
    dm(i7,m1)=r1;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_load_inner_3x3            [official source label]   dispatch 0x7C  opcode 0x3E007C7C
//   in=?  out=?    PM 0x2046C   load the 3x3 from the inner bank
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    r15=0x31000;
    r1=r1 and r1;
    if eq jump _L20474;
    r15=0x31800;

// -- load_bone_from_rot_table: player != 0 branch --
_L20474:
    r15=r15+r0;
    i5=r15;
    i7=dm(0x3033f);
    lcntr=0x9, do (pc,0x3) until lce;
    r0=dm(i5,m1);
    nop;
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_load_3x3                  [official source label]   dispatch 0x11  opcode 0x08801111
//   in=9  out=0    PM 0x2047E   9 floats FIFO -> rot (col0,col1,col2)
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    lcntr=0x9, do (pc,0x4) until lce;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    nop;
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_store_inner_3x3           [official source label]   dispatch 0x7D  opcode 0x3E807D7D
//   in=?  out=?    PM 0x20487   store the 3x3 to the inner bank
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    r15=0x31000;
    r1=r1 and r1;
    if eq jump _L2048F;
    r15=0x31800;

// -- store_bone_to_rot_table: player != 0 branch --
_L2048F:
    r15=r15+r0;
    i5=r15;
    i7=dm(0x3033f);
    lcntr=0x9, do (pc,0x2) until lce;
    r0=dm(i7,m1);
    dm(i5,m1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_3x3                   [official source label]   dispatch 0x12  opcode 0x09001212
//   in=0  out=9    PM 0x20496   rot (9 floats) -> FIFO
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    lcntr=0x9, do (pc,0x5) until lce;
    r0=dm(i7,m1);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    nop;
    nop;
    rts;

// ----------------------------------------------------------------------------
// Fn_mov_matrix                [official source label]   dispatch 0x34  opcode 0x1A003434
//   in=1  out=1    PM 0x2049E   copy current matrix (12w) to DM[0x1400000 + arg/4]; outputs 0
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r0=lshift r0 by -2;
    r1=0x1400000;
    r0=r0+r1;
    i6=r0;
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i7,m1);
    dm(i6,m1)=r0;
    r0=0;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_st_unit_mat               [official source label]   dispatch 0x35  opcode 0x1A803535
//   in=2  out=0    PM 0x204AE   current matrix -> unit-matrix cache[player][slot]
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r1=0xff;
    r0=r0 and r1;
    r1=0x1;
    comp(r0,r1);
    r0=0x30420;
    if ne jump _L204B7;
    r0=0x304e0;

// -- store_bone_to_indexed_table: player 1 base address --
_L204B7:
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    r1=r0+r1;
    i6=r1;
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i7,m1);
    dm(i6,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_ld_unit_mat               [official source label]   dispatch 0x36  opcode 0x1B003636
//   in=2  out=0    PM 0x204C2   unit-matrix cache[player][slot] -> current matrix
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r1=0xff;
    r0=r0 and r1;
    r1=0x1;
    comp(r0,r1);
    r0=0x30420;
    if ne jump _L204CB;
    r0=0x304e0;

// -- load_bone_from_indexed_table: player 1 base address --
_L204CB:
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    r1=r0+r1;
    i6=r1;
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i6,m1);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ==============================================================================
// _L204D6  LOAD_BONE_CACHE_MUL  (PM 0x204D6)  dispatch index 0x37  opcode 0x1B803737
// Read player+slot index from FIFO, load 12 floats from bone table to PM,
// multiply with current bone via _L201E9, write 12 results back to bone slot.
// ==============================================================================

// ----------------------------------------------------------------------------
// Fn_mul_unit_mat              [official source label]   dispatch 0x37  opcode 0x1B803737
//   in=2  out=0    PM 0x204D6   current = cache[player][slot] * current
// ----------------------------------------------------------------------------
_L204D6:
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r1=0xff;
    r0=r0 and r1;
    r1=0x1;
    comp(r0,r1);
    r0=0x30420;
    if ne jump _L204DF;
    r0=0x304e0;

// -- load_bone_cache_mul: player 1 table address --
_L204DF:
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    r1=r0+r1;
    i6=r1;
    i8=0x21f00;
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i6,m1);
    pm(i8,m9)=r0;
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    i7=dm(0x3033f);
    i9=0x21f0c;
    call _L201E9;
    lcntr=0xc, do (pc,0x2) until lce;
    r0=pm(i9,m9);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_coli_trans_mat            [official source label]   dispatch 0x3D  opcode 0x1E803D3D
//   in=6  out=0    PM 0x204F2   collision-space matrix transform
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r8=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r9=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r10=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r12=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r13=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r14=dm(m0,i0);
    r0=0x30429;
    i6=r0;
    r1=0xc0;
    r1=r0+r1;
    i7=r1;
    lcntr=0x10, do (pc,0xe) until lce;
    r4=dm(m0,i6);
    f0=f4+f8, r5=dm(m1,i6);
    f1=f5+f9, r6=dm(m2,i6);
    f2=f6+f10, dm(i6,m1)=r0;
    dm(i6,m1)=r1;
    dm(i6,0xa)=r2;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r4=dm(m0,i7);
    f0=f4+f12, r5=dm(m1,i7);
    f1=f5+f13, r6=dm(m2,i7);
    f2=f6+f14, dm(i7,m1)=r0;
    dm(i7,m1)=r1;
    dm(i7,0xa)=r2;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_calc_unit                 [official source label]   dispatch 0x40  opcode 0x20004040
//   in=0  out=0    PM 0x20515   STUB in this revision (bare rts at PM 0x20515)
// ----------------------------------------------------------------------------
    rts;

// ==============================================================================
// _L20516  ORIENT_XZ  (PM 0x20516)  dispatch index 0x41
// Build XZ-plane orientation in current bone slot.
// Normalizes via _L2029B. No i960 opcode identified yet.
// ==============================================================================

// ----------------------------------------------------------------------------
// Fn_kage_leave_x_axis         [official source label]   dispatch 0x41  opcode 0x20804141
//   in=?  out=?    PM 0x20516   reorient the matrix keeping the X axis (shadow/kage helper)
// ----------------------------------------------------------------------------
_L20516:
    i7=dm(0x3033f);
    r0=dm(0,i7);
    f11=f0*f0, r1=dm(0x2,i7);
    f15=f1*f1;
    f5=f11+f15;
    call _L2029B;
    f0=f0*f4;
    f1=f1*f4;
    dm(0x3,i7)=r0;
    dm(0x5,i7)=r1;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x5,i7);
    f0=-f0, r1=dm(0x3,i7);
    dm(0x6,i7)=r0;
    dm(0x8,i7)=r1;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L20529  ORIENT_YZ  (PM 0x20529)  dispatch index 0x42
// Build YZ-plane orientation in current bone slot.
// No i960 opcode identified yet.
// ==============================================================================

// ----------------------------------------------------------------------------
// Fn_kage_leave_z_axis         [official source label]   dispatch 0x42  opcode 0x21004242
//   in=?  out=?    PM 0x20529   reorient the matrix keeping the Z axis (shadow/kage helper)
// ----------------------------------------------------------------------------
_L20529:
    i7=dm(0x3033f);
    r0=dm(0x6,i7);
    f11=f0*f0, r1=dm(0x8,i7);
    f15=f1*f1;
    f5=f11+f15;
    call _L2029B;
    f0=f0*f4;
    f1=f1*f4;
    dm(0x3,i7)=r0;
    dm(0x5,i7)=r1;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x3,i7);
    f0=-f0, r1=dm(0x5,i7);
    dm(0x2,i7)=r0;
    dm(0,i7)=r1;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ----------------------------------------------------------------------------
// Fn_get_matrix_inner          [official source label]   dispatch 0x43  opcode 0x21804343
//   in=1  out=0    PM 0x2053C   current matrix (12w) -> inner bank PM[0x21F20 + 12*n]
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);

// ==============================================================================
// _L2053E  STORE_BONE_TO_PM_INDEXED  (PM 0x2053E)  dispatch index 0x43  opcode 0x21804343
// Read slot index N from FIFO. Copy current bone (12 words) to PM[0x21F20+N*12].
// ==============================================================================
_L2053E:
    r1=0xc;
    r2=0x21f20;
    r3=0;
    lcntr=0xc, do (pc,0x1) until lce;
    r3=r3+r0;
    r0=r2+r3;
    i7=dm(0x3033f);
    i8=r0;
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i7,m1);
    pm(i8,m9)=r0;
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_load_matrix_inner         [official source label]   dispatch 0x44  opcode 0x22004444
//   in=1  out=0    PM 0x2054C   inner bank PM[0x21F20 + 12*n] -> current matrix
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r1=0xc;
    r2=0x21f20;
    r3=0;
    lcntr=0xc, do (pc,0x1) until lce;
    r3=r3+r0;
    r0=r2+r3;
    i7=dm(0x3033f);
    i8=r0;
    lcntr=0xc, do (pc,0x2) until lce;
    r0=pm(i8,m9);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_mul_matrix_inner          [official source label]   dispatch 0x45  opcode 0x22804545
//   in=1  out=0    PM 0x2055C   current = inner[n] * current  (_L201EA)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r1=0xc;
    r2=0x21f20;
    r3=0;
    lcntr=0xc, do (pc,0x1) until lce;
    r3=r3+r0;
    r0=r2+r3;
    i7=dm(0x3033f);
    i8=r0;
    i9=0x21f0c;
    call _L201EA;
    lcntr=0xc, do (pc,0x2) until lce;
    r0=pm(i9,m9);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ==============================================================================
// _L2056E  MUL_BONE_BY_PM_INDEXED  (PM 0x2056E)  dispatch index 0x46  opcode 0x23004646
// Read slot index from FIFO. Multiply current bone by PM-cached matrix, result -> bone.
// ==============================================================================

// ----------------------------------------------------------------------------
// Fn_mul_matrix_inner_rev      [official source label]   dispatch 0x46  opcode 0x23004646
//   in=1  out=0    PM 0x2056E   current = current * inner[n]
// ----------------------------------------------------------------------------
_L2056E:
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r1=0xc;
    r2=0x21f20;
    r3=0;
    lcntr=0xc, do (pc,0x1) until lce;
    r3=r3+r0;
    r0=r2+r3;
    i7=dm(0x3033f);
    i8=r0;
    call _L2021F;
    rts;

// ----------------------------------------------------------------------------
// Fn_mul_matrix_rev            [official source label]   dispatch 0x47  opcode 0x23804747
//   in=12 out=0    PM 0x2057A   12 floats FIFO = M; current = current * M  (_L2021E)
// ----------------------------------------------------------------------------
    i8=0x21f00;
    lcntr=0xc, do (pc,0x4) until lce;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    nop;
    pm(i8,m9)=r0;
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    i7=dm(0x3033f);
    call _L2021E;
    rts;

// ----------------------------------------------------------------------------
// Fn_read_ram                  [official source label]   dispatch 0x48  opcode 0x24004848
//   in=1  out=1    PM 0x20585   DM[arg] -> FIFO
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    i7=r1;
    r0=dm(i7,m0);
    nop;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_write_ram                 [official source label]   dispatch 0x49  opcode 0x24804949
//   in=2  out=0    PM 0x2058D   DM[arg0] = arg1
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    i7=r1;
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    nop;
    dm(i7,m0)=r2;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_st_glb_mat                [official source label]   dispatch 0x67  opcode 0x33806767
//   in=1  out=0    PM 0x20597   store the current matrix into global matrix slot n
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r1=0x1400000;
    r0=r0+r1;
    i6=r0;
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i7,m1);
    dm(i6,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_ld_glb_mat                [official source label]   dispatch 0x68  opcode 0x34006868
//   in=1  out=0    PM 0x205A3   load the current matrix from global matrix slot n
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r1=0x1400000;
    r0=r0+r1;
    i6=r0;
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i6,m1);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_x_rot_e                   [official source label]   dispatch 0x6C  opcode 0x36006C6C
//   in=0  out=0    PM 0x205AF   STUB in this revision (bare rts at PM 0x205AF)
// Fn_y_rot_e                   [official source label]   dispatch 0x6D  opcode 0x36806D6D
//   in=0  out=0    PM 0x205AF   STUB in this revision (bare rts at PM 0x205AF)
// Fn_z_rot_e                   [official source label]   dispatch 0x6E  opcode 0x37006E6E
//   in=0  out=0    PM 0x205AF   STUB in this revision (bare rts at PM 0x205AF)
// Fn_trans_e                   [official source label]   dispatch 0x6F  opcode 0x37806F6F
//   in=0  out=0    PM 0x205AF   STUB in this revision (bare rts at PM 0x205AF)
// ----------------------------------------------------------------------------
    rts;

// ----------------------------------------------------------------------------
// Fn_add                       [official source label]   dispatch 0x13  opcode 0x09801313
//   in=2  out=1    PM 0x205B0   (a + b) -> float
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    f0=f1+f2;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_sub                       [official source label]   dispatch 0x14  opcode 0x0A001414
//   in=2  out=1    PM 0x205B8   (a - b) -> float
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    f0=f1-f2;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_mul                       [official source label]   dispatch 0x15  opcode 0x0A801515
//   in=2  out=1    PM 0x205C0   (a * b) -> float
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    f0=f2*f1;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_div                       [official source label]   dispatch 0x16  opcode 0x0B001616
//   in=2  out=1    PM 0x205C8   (a / b) -> float
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    call _L205D0;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ==============================================================================
// _L205D0  FLOAT_RECIP_MUL  (PM 0x205D0)  helper
// f0 = f1/f2 via SHARC recips seed + 3 Newton-Raphson iterations.
// Entry: f1=numerator, f2=denominator, r4=1.0, r11=2.0.
// ==============================================================================
_L205D0:
    f3=recips f2, r4=r1;
    f12=f3*f2, r11=dm(m2,i3);
    f4=f3*f4, f3=f11-f12;
    f12=f3*f12;
    f4=f3*f4, f3=f11-f12;
    rts (db), f12=f3*f12;
    f4=f3*f4, f3=f11-f12;
    f0=f3*f4;

// ----------------------------------------------------------------------------
// Fn_cvtws                     [official source label]   dispatch 0x17  opcode 0x0B801717
//   in=1  out=1    PM 0x205D8   int -> float
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    f0=float r1;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_cvtsw                     [official source label]   dispatch 0x18  opcode 0x0C001818
//   in=1  out=1    PM 0x205DE   float -> int (truncate)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    r0=fix f1;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_sqr_r                     [official source label]   dispatch 0x19  opcode 0x0C801919
//   in=1  out=1    PM 0x205E4   1/sqrt(a): rsqrts seed + 3 Newton iterations (_L2029B)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r5=dm(m0,i0);
    call _L2029B;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r4;
    rts;

// ----------------------------------------------------------------------------
// Fn_sqr                       [official source label]   dispatch 0x1A  opcode 0x0D001A1A
//   in=1  out=1    PM 0x205EA   sqrt(a)  (_L202AE)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L202AE;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_put_c                     [official source label]   dispatch 0x1B  opcode 0x0D801B1B
//   in=1  out=0    PM 0x205F0   C = arg          -- C is the scalar accumulator at DM[0x30400]
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    dm(0x30400)=r1;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_c                     [official source label]   dispatch 0x1C  opcode 0x0E001C1C
//   in=0  out=1    PM 0x205F4   C -> FIFO
// ----------------------------------------------------------------------------
    r0=dm(0x30400);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_add_c                     [official source label]   dispatch 0x1D  opcode 0x0E801D1D
//   in=1  out=0    PM 0x205F8   C = C + arg
// ----------------------------------------------------------------------------
    r1=dm(0x30400);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    rts (db);
    f0=f1+f2;
    dm(0x30400)=r0;

// ----------------------------------------------------------------------------
// Fn_sub_c                     [official source label]   dispatch 0x1E  opcode 0x0F001E1E
//   in=1  out=0    PM 0x205FE   C = C - arg
// ----------------------------------------------------------------------------
    r1=dm(0x30400);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    rts (db);
    f0=f1-f2;
    dm(0x30400)=r0;

// ----------------------------------------------------------------------------
// Fn_mul_c                     [official source label]   dispatch 0x1F  opcode 0x0F801F1F
//   in=1  out=0    PM 0x20604   C = C * arg
// ----------------------------------------------------------------------------
    r1=dm(0x30400);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    rts (db);
    f0=f1*f2;
    dm(0x30400)=r0;

// ----------------------------------------------------------------------------
// Fn_div_c                     [official source label]   dispatch 0x20  opcode 0x10002020
//   in=1  out=0    PM 0x2060A   C = C / arg  (_L205D0)
// ----------------------------------------------------------------------------
    r1=dm(0x30400);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    call _L205D0;
    dm(0x30400)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_sin                       [official source label]   dispatch 0x21  opcode 0x10802121
//   in=1  out=1    PM 0x20610   sin(i16 angle) -> float
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L202C1;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r1;
    rts;

// ----------------------------------------------------------------------------
// Fn_cos                       [official source label]   dispatch 0x22  opcode 0x11002222
//   in=1  out=1    PM 0x20616   cos(i16 angle) -> float
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L202C1;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_tan                       [official source label]   dispatch 0x23  opcode 0x11802323
//   in=1  out=1    PM 0x2061C   tan(i16 angle) -> float
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L202C1;
    r2=r0;
    call _L205D0;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_sinx                      [official source label]   dispatch 0x24  opcode 0x12002424
//   in=2  out=1    PM 0x20624   sin(i16 angle) * scale -> float
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L202C1;
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    f0=f1*f4;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_cosx                      [official source label]   dispatch 0x25  opcode 0x12802525
//   in=2  out=1    PM 0x2062D   cos(i16 angle) * scale -> float
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L202C1;
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    f0=f0*f4;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_asin                      [official source label]   dispatch 0x26  opcode 0x13002626
//   in=1  out=1    PM 0x20636   asin(a) -> i16 angle  (_L20332)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    call _L20332;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_atan                      [official source label]   dispatch 0x27  opcode 0x13802727
//   in=2  out=1    PM 0x2063C   atan2(y, x) -> i16 angle
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    call _L202CA;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_tri_shin                  [official source label]   dispatch 0x28  opcode 0x14002828
//   in=3  out=3    PM 0x20644   triangle solve (law of cosines): 3 sides -> 2 i16 angles + 1 float
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    dm(0x3,i3)=r1;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    f8=f0*f0, r6=r2;
    f12=f1*f1, r7=dm(m2,i3);
    f13=f2*f6, f9=f8-f12;
    call _L205D0 (db);
    f3=f0*f6, f1=f9+f13;
    f2=f3*f7;
    r1=r0;
    call _L20332;
    r3=0x4000;
    r3=r3-r0;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r3;
    f11=f12+f13, r7=dm(m2,i3);
    r0=dm(0x3,i3);
    f1=f11-f8;
    call _L205D0 (db);
    dm(0x10,i3)=r11;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    f2=f0*f7;
    r11=dm(0x10,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    call _L202AE (db);
    f8=f11*f11;
    f0=f13-f8;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_point_trans               [official source label]   dispatch 0x29  opcode 0x14802929
//   in=3  out=3    PM 0x2066A   local -> world: rot*(x,y,z) + T
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    i7=dm(0x3033f);
    call _L20173;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r8;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r9;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r10;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_inner                 [official source label]   dispatch 0x2A  opcode 0x15002A2A
//   in=6  out=1    PM 0x20679   3D dot product; args interleaved (a.x,b.x,a.y,b.y,a.z,b.z)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r5=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r6=dm(m0,i0);
    f8=f0*f4;
    f12=f1*f5;
    f12=f2*f6, f8=f8+f12;
    f8=f8+f12;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r8;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_inner_2d              [official source label]   dispatch 0x59  opcode 0x2C805959
//   in=4  out=1    PM 0x2068C   2D dot product: a*b + c*d
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r5=dm(m0,i0);
    f8=f0*f4;
    f12=f1*f5;
    f8=f8+f12;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r8;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_2d_r                  [official source label]   dispatch 0x2B  opcode 0x15802B2B
//   in=4  out=1    PM 0x2069A   distance between two points in XZ
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r5=dm(m0,i0);
    f8=f0-f4;
    f9=f1-f5;
    f11=f8*f8;
    f12=f9*f9;
    f0=f11+f12;
    call _L202AE;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_3d_r                  [official source label]   dispatch 0x2C  opcode 0x16002C2C
//   in=6  out=1    PM 0x206AB   distance between two 3D points
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r5=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r6=dm(m0,i0);
    f8=f0-f4;
    f9=f1-f5;
    f10=f2-f6;
    f11=f8*f8;
    f12=f9*f9;
    f13=f10*f10;
    f11=f11+f12;
    f0=f11+f13;
    call _L202AE;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_2d_len                [official source label]   dispatch 0x2D  opcode 0x16802D2D
//   in=2  out=1    PM 0x206C3   sqrt(a^2 + b^2)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    call _L20352;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_3d_len                [official source label]   dispatch 0x2E  opcode 0x17002E2E
//   in=3  out=1    PM 0x206CB   sqrt(x^2 + y^2 + z^2)  (_L2034C)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    call _L2034C;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_2d_dir                [official source label]   dispatch 0x2F  opcode 0x17802F2F
//   in=4  out=1    PM 0x206D5   atan2(z2-z1, x2-x1) -> i16 angle
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r5=dm(m0,i0);
    f0=f4-f0;
    f1=f5-f1;
    call _L202CA;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_regular_vector            [official source label]   dispatch 0x30  opcode 0x18003030
//   in=3  out=3    PM 0x206E3   normalise a 3D vector: v * 1/|v|  (_L20356)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    call _L20356;
    f8=f0*f4;
    f9=f1*f4;
    f10=f2*f4;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r8;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r9;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r10;
    rts;

// ----------------------------------------------------------------------------
// Fn_regular_vector_2d         [official source label]   dispatch 0x5A  opcode 0x2D005A5A
//   in=2  out=2    PM 0x206F4   normalise a 2D vector: v * 1/|v|  (_L2035C)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    call _L2035C;
    f8=f0*f4;
    f9=f1*f4;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r8;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r9;
    rts;

// ----------------------------------------------------------------------------
// Fn_rot_2d                    [official source label]   dispatch 0x5B  opcode 0x2D805B5B
//   in=3  out=2    PM 0x20700   rotate (x,y) by an i16 angle -> (x*cos - y*sin, y*cos + x*sin)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L202C1;
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r5=dm(m0,i0);
    f8=f0*f4;
    f12=f1*f5;
    f9=f1*f4, f8=f8-f12;
    f13=f0*f5;
    f9=f9+f13;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r8;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r9;
    rts;

// ----------------------------------------------------------------------------
// Fn_add3                      [official source label]   dispatch 0x5C  opcode 0x2E005C5C
//   in=6  out=3    PM 0x20711   vector add: (a0+a1, a2+a3, a4+a5)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r8=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r12=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r9=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r13=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r10=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r14=dm(m0,i0);
    f8=f8+f12;
    f9=f9+f13;
    f10=f10+f14;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r8;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r9;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r10;
    rts;

// ----------------------------------------------------------------------------
// Fn_sub3                      [official source label]   dispatch 0x5D  opcode 0x2E805D5D
//   in=6  out=3    PM 0x20727   vector subtract: (a0-a1, a2-a3, a4-a5)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r8=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r12=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r9=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r13=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r10=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r14=dm(m0,i0);
    f8=f8-f12;
    f9=f9-f13;
    f10=f10-f14;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r8;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r9;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r10;
    rts;

// ----------------------------------------------------------------------------
// Fn_mul3                      [official source label]   dispatch 0x5E  opcode 0x2F005E5E
//   in=4  out=3    PM 0x2073D   scalar * vector: (s*x, s*y, s*z)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r3=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r5=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r6=dm(m0,i0);
    f8=f3*f4;
    f9=f3*f5;
    f10=f3*f6;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r8;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r9;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r10;
    rts;

// ----------------------------------------------------------------------------
// Fn_div3                      [official source label]   dispatch 0x5F  opcode 0x2F805F5F
//   in=0  out=0    PM 0x2074F   STUB in this revision (bare rts at PM 0x2074F)
// ----------------------------------------------------------------------------
    rts;

// ----------------------------------------------------------------------------
// Fn_glo_to_loc                [official source label]   dispatch 0x6A  opcode 0x35006A6A
//   in=3  out=3    PM 0x20750   world -> local: rot^T * (v - T)
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r4=dm(0x9,i7);
    r5=dm(0xa,i7);
    r6=dm(0xb,i7);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    f0=f0-f4;
    f1=f1-f5;
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    f2=f2-f6, r4=dm(0,i7);
    f8=f0*f4, r5=dm(0x3,i7);
    f9=f0*f5, r6=dm(0x6,i7);
    f10=f0*f6, r4=dm(0x1,i7);
    f12=f1*f4, r5=dm(0x4,i7);
    f13=f1*f5, f8=f8+f12, r6=dm(0x7,i7);
    f14=f1*f6, f9=f9+f13, r4=dm(0x2,i7);
    f12=f2*f4, f10=f10+f14, r5=dm(0x5,i7);
    f13=f2*f5, f8=f8+f12, r6=dm(0x8,i7);
    f14=f2*f6, f9=f9+f13;
    f10=f10+f14;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r8;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r9;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r10;
    rts;

// ----------------------------------------------------------------------------
// Fn_osage                     [official source label]   dispatch 0x4A  opcode 0x25004A4A
//   in=1  out=0    PM 0x2076E   "osage" dangling/cloth sim: streaming typed-block data reader
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r1=0x1400000;
    r0=r0+r1;
    dm(0x30340)=r0;
    i6=0x30392;
    dm(i6,m1)=0x20784;
    dm(i6,m1)=0x20785;
    dm(i6,m1)=0x2079c;
    dm(i6,m1)=0x207a7;
    dm(i6,m1)=0x207b2;
    dm(i6,m1)=0x207bd;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L2077C  ANIM_STREAM_LOOP  (PM 0x2077C)
// Streaming typed-block reader used by read_anim_data (index 0x4A, opcode 0x25004A4A).
// Reads a type byte from current data pointer DM[0x30340], dispatches sub-handlers
// via local jump table at DM[0x30392], loops back until an end-marker block.
// ==============================================================================
_L2077C:
    i6=dm(0x30340);
    r0=dm(i6,m1);
    nop;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    i7=r0;
    i15=dm(0x30392,i7);
    jump (m8,i15);
    rts;
    r0=dm(0x30340);
    r1=0x25;
    r0=r0+r1;
    dm(0x30340)=r0;
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i6,m1);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    i7=0x3037a;
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i6,m1);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    i7=0x30386;
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i6,m1);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    jump _L2077C;
    r0=dm(0x30340);
    r1=0x1f;
    r0=r0+r1;
    dm(0x30340)=r0;
    i7=0x30342;
    lcntr=0x1e, do (pc,0x2) until lce;
    r0=dm(i6,m1);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    jump _L2077C;
    r0=dm(0x30340);
    r1=0x3;
    r0=r0+r1;
    dm(0x30340)=r0;
    i7=0x30360;
    lcntr=0x2, do (pc,0x2) until lce;
    r0=dm(i6,m1);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    jump _L2077C;
    r0=dm(0x30340);
    r1=0x4;
    r0=r0+r1;
    dm(0x30340)=r0;
    i7=0x30362;
    lcntr=0x3, do (pc,0x2) until lce;
    r0=dm(i6,m1);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    jump _L2077C;
    r0=dm(0x30340);
    r1=0xc;
    r0=r0+r1;
    dm(0x30340)=r0;
    dm(0x30341)=i6;
    r0=dm(0x8,i6);
    dm(0x3036b)=r0;
    r0=dm(0x9,i6);
    dm(0x3036c)=r0;
    r0=dm(0xa,i6);
    dm(0x3036d)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x30362);
    dm(0x30377)=r0;
    r0=dm(0x30363);
    dm(0x30378)=r0;
    r0=dm(0x30364);
    dm(0x30379)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0,i6);
    r1=dm(0x1,i6);
    call _L20173 (db);
    r2=dm(0x2,i6);
    i7=0x3037a;
    dm(0x30365)=r8;
    dm(0x30366)=r9;
    dm(0x30367)=r10;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x3,i6);
    r1=dm(0x4,i6);
    call _L20173 (db);
    r2=dm(0x5,i6);
    i7=0x30386;
    dm(0x30368)=r8;
    dm(0x30369)=r9;
    dm(0x3036a)=r10;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x30365);
    r1=dm(0x30366);
    r2=dm(0x30367);
    r3=dm(0x30368);
    f0=f0+f3;
    r3=dm(0x30369);
    f1=f1+f3;
    r3=dm(0x3036a);
    f2=f2+f3;
    r3=dm(0x3036b);
    f0=f0+f3;
    r3=dm(0x3036c);
    f1=f1+f3;
    jump _L2084B (db);
    r3=dm(0x3036d);
    f2=f2+f3;

// ==============================================================================
// _L207F6  IK_SOLVE_ITERATION  (PM 0x207F6)
// Core IK iteration: normalize direction to target, compute rotation,
// apply ang_y to current bone, recompute world position.
// ==============================================================================
_L207F6:
    r4=dm(0x30362);
    f0=f0-f4;
    r4=dm(0x30363);
    f1=f1-f4;
    call _L20356 (db);
    r4=dm(0x30364);
    f2=f2-f4;
    f8=f0*f4;
    f9=f1*f4;
    f10=f2*f4;
    dm(0x3,i3)=r8;
    dm(0x4,i3)=r9;
    dm(0x5,i3)=r10;
    dm(0x30371)=r8;
    dm(0x30372)=r9;
    dm(0x30373)=r10;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    f0=f10*f10;
    call _L2029B (db);
    r1=0x3f800000;
    f5=f1-f0;
    f5=f5*f4;
    dm(0x30376)=r5;
    f3=f4*f9;
    dm(0x3036e)=r3;
    f3=f3*f10;
    r11=0xbf800000;
    f3=f3*f11;
    dm(0x30375)=r3;
    f3=f4*f8;
    f3=f3*f11;
    dm(0x3036f)=r3;
    f3=f3*f10;
    dm(0x30374)=r3;
    r3=0;
    dm(0x30370)=r3;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    i7=dm(0x3033f);
    call _L201EA (db);
    i8=0x3036e;
    i9=0x21f0c;
    lcntr=0xc, do (pc,0x8) until lce;
    r0=pm(i9,m9);
    nop;
    nop;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    nop;
    nop;
    i6=dm(0x30341);
    r5=dm(0x7,i6);
    r0=dm(0x3,i3);
    f8=f0*f5, r1=dm(0x4,i3);
    f9=f1*f5, r2=dm(0x5,i3);
    f10=f2*f5;
    r0=dm(0x30362);
    f8=f8+f0;
    r1=dm(0x30363);
    f9=f9+f1;
    r2=dm(0x30364);
    f10=f10+f2;
    r5=dm(0x30361);
    dm(0,i6)=r8;
    r0=dm(0x30365);
    f0=f8-f0;
    f0=f0*f5;
    dm(0x1,i6)=r9;
    r1=dm(0x30366);
    f1=f9-f1;
    f1=f1*f5;
    dm(0x2,i6)=r10;
    r2=dm(0x30367);
    f2=f10-f2;
    f2=f2*f5;
    dm(0x3,i6)=r0;
    dm(0x30362)=r8;
    dm(0x4,i6)=r1;
    dm(0x30363)=r9;
    dm(0x5,i6)=r2;
    dm(0x30364)=r10;
    jump _L2077C (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L2084B  IK_CONSTRAINT_EVAL  (PM 0x2084B)
// Evaluate joint constraint: dot(chain_dir, target_dir), check cone limit.
// Branches to _L2085D if outside allowed range.
// ==============================================================================
_L2084B:
    r8=dm(0x30342);
    r9=dm(0x30343);
    r10=dm(0x30344);
    f3=f8*f0;
    f4=f9*f1;
    f5=f10*f2;
    f3=f3+f4;
    f3=f3+f5;
    r4=dm(0x30345);
    f3=f4-f3;
    if lt jump _L2085D;
    f8=f8*f3;
    f9=f9*f3;
    f10=f10*f3;
    f0=f0+f8;
    jump _L207F6 (db);
    f1=f1+f9;
    f2=f2+f10;

// ==============================================================================
// _L2085D  IK_CONSTRAINT_CLAMP  (PM 0x2085D)
// Target outside joint constraint. Clamp and re-run solve iteration.
// ==============================================================================
_L2085D:
    r3=0x1;
    r4=dm(0x30360);
    comp(r3,r4);
    if eq jump _L207F6;
    r3=0;
    comp(f1,f3);
    if lt jump _L208A2;
    r3=dm(0x30350);
    comp(f1,f3);
    if gt jump _L20873;
    f3=f0*f0;
    f4=f1*f1;
    f5=f3+f4;
    r4=dm(0x30351);
    comp(f4,f5);
    if lt jump _L2088A;
    call _L2029B;
    r3=dm(0x30350);
    f3=f3*f4;
    jump _L2088A (db);
    f0=f0*f3;
    f1=f1*f3;

// -- IK constraint: check upper angular limit --
_L20873:
    r13=dm(0x30346);
    r14=dm(0x30347);
    r15=dm(0x30348);
    f8=f0-f13;
    f9=f1-f14;
    f10=f2-f15;
    f3=f8*f8;
    f4=f9*f9;
    f5=f10*f10;
    f5=f5+f4;
    f5=f5+f3;
    r4=dm(0x3034a);
    comp(f4,f5);
    if lt jump _L2088A;
    call _L2029B;
    r3=dm(0x30349);
    f3=f3*f4;
    f8=f8*f3;
    f9=f9*f3;
    f10=f10*f3;
    f0=f13+f8;
    f1=f14+f9;
    f2=f15+f10;

// -- IK constraint: check second angular ring --
_L2088A:
    r13=dm(0x3034b);
    r14=dm(0x3034c);
    r15=dm(0x3034d);
    f8=f0-f13;
    f9=f1-f14;
    f10=f2-f15;
    f3=f8*f8;
    f4=f9*f9;
    f5=f10*f10;
    f5=f5+f4;
    f5=f5+f3;
    r4=dm(0x3034f);
    comp(f4,f5);
    if lt jump _L207F6;
    call _L2029B;
    r3=dm(0x3034e);
    f3=f3*f4;
    f8=f8*f3;
    f9=f9*f3;
    f10=f10*f3;
    f0=f13+f8;
    jump _L207F6 (db);
    f1=f14+f9;
    f2=f15+f10;

// -- IK constraint: y-component negative branch --
_L208A2:
    r3=0;
    comp(f0,f3);
    if lt jump _L208C2;
    r3=dm(0x30358);
    comp(f1,f3);
    if gt jump _L208B5;
    r8=dm(0x3035a);
    r9=dm(0x3035b);
    f3=f8*f0;
    f4=f9*f1;
    f3=f3+f4;
    r4=dm(0x3035c);
    f3=f4-f3;
    if lt jump _L207F6;
    f8=f8*f3;
    f9=f9*f3;
    jump _L207F6 (db);
    f0=f0+f8;
    f1=f1+f9;

// -- IK constraint: +x side zone --
_L208B5:
    r8=dm(0x30352);
    r9=dm(0x30353);
    f3=f8*f0;
    f4=f9*f1;
    f3=f3+f4;
    r4=dm(0x30354);
    f3=f4-f3;
    if lt jump _L207F6;
    f8=f8*f3;
    f9=f9*f3;
    jump _L207F6 (db);
    f0=f0+f8;
    f1=f1+f9;

// -- IK constraint: -x side branch --
_L208C2:
    r3=dm(0x30359);
    comp(f1,f3);
    if gt jump _L208D2;
    r8=dm(0x3035d);
    r9=dm(0x3035e);
    f3=f8*f0;
    f4=f9*f1;
    f3=f3+f4;
    r4=dm(0x3035f);
    f3=f4-f3;
    if lt jump _L207F6;
    f8=f8*f3;
    f9=f9*f3;
    jump _L207F6 (db);
    f0=f0+f8;
    f1=f1+f9;

// -- IK constraint: -y/-x corner zone --
_L208D2:
    r8=dm(0x30355);
    r9=dm(0x30356);
    f3=f8*f0;
    f4=f9*f1;
    f3=f3+f4;
    r4=dm(0x30357);
    f3=f4-f3;
    if lt jump _L207F6;
    f8=f8*f3;
    f9=f9*f3;
    jump _L207F6 (db);
    f0=f0+f8;
    f1=f1+f9;

// ----------------------------------------------------------------------------
// Fn_ken2                      [official source label]   dispatch 0x4B  opcode 0x25804B4B
//   in=0  out=0    PM 0x208DF   STUB in this revision (bare rts at PM 0x208DF)
// Fn_ken3                      [official source label]   dispatch 0x4C  opcode 0x26004C4C
//   in=0  out=0    PM 0x208DF   STUB in this revision (bare rts at PM 0x208DF)
// Fn_ken4                      [official source label]   dispatch 0x4D  opcode 0x26804D4D
//   in=0  out=0    PM 0x208DF   STUB in this revision (bare rts at PM 0x208DF)
// Fn_ken5                      [official source label]   dispatch 0x4E  opcode 0x27004E4E
//   in=0  out=0    PM 0x208DF   STUB in this revision (bare rts at PM 0x208DF)
// Fn_2d_coli_put               [official source label]   dispatch 0x64  opcode 0x32006464
//   in=0  out=0    PM 0x208DF   STUB in this revision (bare rts at PM 0x208DF)
// Fn_2d_coli_coli              [official source label]   dispatch 0x65  opcode 0x32806565
//   in=0  out=0    PM 0x208DF   STUB in this revision (bare rts at PM 0x208DF)
// Fn_2d_coli_get               [official source label]   dispatch 0x66  opcode 0x33006666
//   in=0  out=0    PM 0x208DF   STUB in this revision (bare rts at PM 0x208DF)
// ----------------------------------------------------------------------------
    rts;

// ----------------------------------------------------------------------------
// Fn_coli_dist                 [official source label]   dispatch 0x33  opcode 0x19803333
//   in=0  out=0    PM 0x208E0   STUB in this revision (bare rts at PM 0x208E0, shared with Fn_coli_sink)
// Fn_coli_sink                 [official source label]   dispatch 0x3C  opcode 0x1E003C3C
//   in=0  out=0    PM 0x208E0   STUB in this revision (bare rts at PM 0x208E0, shared with Fn_coli_dist)
// ----------------------------------------------------------------------------
    rts;

// ----------------------------------------------------------------------------
// Fn_zanzou_init               [official source label]   dispatch 0x81  opcode 0x40808181
//   in=0  out=0    PM 0x208E1   afterimage ("zanzou") init
// ----------------------------------------------------------------------------
    i6=0x32180;
    r0=0;
    lcntr=0x5480, do (pc,0x1) until lce;
    dm(i6,m1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_zanzou_get_info           [official source label]   dispatch 0x85  opcode 0x42808585
//   in=1  out=0    PM 0x208E6   read afterimage info
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r2=0x32300;
    r3=0;
    lcntr=0x20, do (pc,0x1) until lce;
    r3=r3+r0;
    r0=r2+r3;
    i6=r0;
    r2=dm(0,i6);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r2;
    r2=dm(0x1,i6);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r2;
    r3=dm(0x2,i6);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r3;
    r2=dm(0x3,i6);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r2;
    btst r2 by 0x1f;
    if sz jump _L208FE;
    r0=0;
    r2=r0-r2;
_L208FE:
    r10=lshift r2 by -1;
    r0=0x14;
    r10=r10+r2;
    r11=lshift r2 by -2;
    r11=r11-1;
    r12=lshift r11 by 0x3;
    r11=r12-r11;
    r0=0x28;
    r11=r11+r0;
    r2=dm(0x4,i6);
    comp(r11,r3);
    if lt jump _L2090E;
    r2=dm(0x5,i6);
    comp(r10,r3);
    if lt jump _L2090E;
    r2=dm(0x6,i6);
_L2090E:
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r2;
    rts;

// ----------------------------------------------------------------------------
// Fn_zanzou_inc                [official source label]   dispatch 0x82  opcode 0x41008282
//   in=0  out=1    PM 0x20911   afterimage ("zanzou") counter increment -> int
// ----------------------------------------------------------------------------
    r2=0;
    i6=0x32300;
    m7=0x20;
    lcntr=0x80, do (pc,0xc) until lce;
    r1=dm(0x2,i6);
    r1=r1 and r1;
    if eq jump _L20920;
    r7=dm(0x3,i6);
    r1=r1+r7;
    r2=r2+1;
    btst r1 by 0x1f;
    if sz jump _L2091F;
    r2=r2-1;
    r1=0;
_L2091F:
    dm(0x2,i6)=r1;
_L20920:
    r0=dm(i6,m7);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r2;
    rts;

// ----------------------------------------------------------------------------
// Fn_zanzou_mul_matrix_inner   [official source label]   dispatch 0x84  opcode 0x42008484
//   in=1  out=0    PM 0x20926   multiply an afterimage matrix from the inner bank
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r6=dm(m0,i0);
    r2=0x32314;
    r3=0;
    lcntr=0x20, do (pc,0x1) until lce;
    r3=r3+r6;
    r6=r2+r3;
    i7=dm(0x3033f);
    i8=r6;
    i9=0x21f0c;
    call _L201EA;
    lcntr=0xc, do (pc,0x2) until lce;
    r6=pm(i9,m9);
    dm(i7,m1)=r6;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_zanzou_load_matrix_inner  [official source label]   dispatch 0x83  opcode 0x41808383
//   in=?  out=?    PM 0x20937   load an afterimage matrix from the inner bank
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r6=dm(m0,i0);
    r2=0x32314;
    r3=0;
    lcntr=0x20, do (pc,0x1) until lce;
    r3=r3+r6;
    r6=r2+r3;
    i7=dm(0x3033f);
    i8=r6;
    lcntr=0xc, do (pc,0x2) until lce;
    r6=pm(i8,m9);
    dm(i7,m1)=r6;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_zanzou_get_matrix_inner   [official source label]   dispatch 0x87  opcode 0x43808787
//   in=?  out=?    PM 0x20946   get an afterimage matrix from the inner bank
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r6=dm(m0,i0);
    r2=0x32314;
    r3=0;
    lcntr=0x20, do (pc,0x1) until lce;
    r3=r3+r6;
    r6=r2+r3;
    i7=dm(0x3033f);
    i8=r6;
    lcntr=0xc, do (pc,0x2) until lce;
    r6=dm(i7,m1);
    pm(i8,m9)=r6;
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_zanzou_kill_timer_buffer  [official source label]   dispatch 0x86  opcode 0x43008686
//   in=1  out=0    PM 0x20955   kill the afterimage timer buffer
// ----------------------------------------------------------------------------
    i6=0x32190;
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    r1=r1 and r1;
    if eq jump _L2095B;
    i6=0x321f0;
_L2095B:
    r0=0;
    lcntr=0x10, do (pc,0x1) until lce;
    dm(i6,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_zanzou_reserve            [official source label]   dispatch 0x80  opcode 0x40008080
//   in=?  out=?    PM 0x20961   reserve an afterimage ("zanzou") slot
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r15=dm(m0,i0);
    dm(0x12,i3)=r15;
    r0=0x1;
    r1=0x30420;
    r2=0x32000;
    i5=0x321a0;
    i6=0x32190;
    i7=0x321e0;
    comp(r15,r0);
    if ne jump _L20971;
    r1=0x304e0;
    r2=0x320c0;
    i5=0x32200;
    i6=0x321f0;
    i7=0x32240;
_L20971:
    dm(0x10,i3)=r1;
    dm(0x11,i3)=r2;
    r3=i5;
    dm(0x13,i3)=r3;
    r3=i6;
    dm(0x14,i3)=r3;
    r3=i7;
    dm(0x15,i3)=r3;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    if flag0_in jump (pc, 0);
    r15=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x18,i3)=r0;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x17,i3)=r0;
    r14=dm(i7,m0);
    r14=r15 xor r14;
    r13=0;
    r0=0;
_L20987:
    btst r14 by r13;
    if sz jump _L2098B;
    m6=r13;
    dm(m6,i6)=r0;
_L2098B:
    r13=r13+1;
    r1=0x10;
    comp(r13,r1);
    if ne jump _L20987;
    dm(i7,m0)=r15;
    r1=-1;
    r2=0x10;
_L20992:
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    comp(r0,r1);
    if eq jump _L209A7;
    m7=r0;
    if flag0_in jump (pc, 0);
    r3=dm(m0,i0);
    dm(m7,i5)=r3;
    r0=r0+r2;
    m7=r0;
    if flag0_in jump (pc, 0);
    r3=dm(m0,i0);
    dm(m7,i5)=r3;
    r0=r0+r2;
    m7=r0;
    if flag0_in jump (pc, 0);
    r3=dm(m0,i0);
    dm(m7,i5)=r3;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    jump _L20992;
_L209A7:
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x16,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r1=0;
    r2=0;
_L209AE:
    btst r15 by r1;
    if sz jump _L209F0;
    r0=0;
    lcntr=0xc, do (pc,0x1) until lce;
    r0=r0+r1;
    r12=dm(0x10,i3);
    r13=dm(0x11,i3);
    r10=r12+r0;
    r11=r13+r0;
    i4=r10;
    i5=r11;
    r3=dm(0x9,i4);
    r4=dm(0xa,i4);
    r5=dm(0xb,i4);
    r6=dm(0x9,i5);
    r7=dm(0xa,i5);
    r8=dm(0xb,i5);
    f3=f3-f6;
    f4=f4-f7;
    f5=f5-f8;
    f3=f3*f3;
    f4=f4*f4;
    f5=f5*f5;
    f3=f3+f4;
    f3=f3+f5;
    comp(f3,f2);
    if lt jump _L209CA;
    r2=r3;
_L209CA:
    r0=dm(0x17,i3);
    r4=dm(0,i4);
    r5=dm(0x1,i4);
    r6=dm(0x2,i4);
    f12=f0*f4, r9=dm(0x9,i4);
    f13=f0*f5, r10=dm(0xa,i4);
    f14=f0*f6, r11=dm(0xb,i4);
    f3=f9+f12;
    f4=f10+f13;
    f5=f11+f14;
    dm(0x3,i3)=r3;
    dm(0x4,i3)=r4;
    dm(0x5,i3)=r5;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r4=dm(0,i5);
    r5=dm(0x1,i5);
    r6=dm(0x2,i5);
    f12=f0*f4, r9=dm(0x9,i5);
    f13=f0*f5, r10=dm(0xa,i5);
    f14=f0*f6, r11=dm(0xb,i5);
    f6=f9+f12;
    f7=f10+f13;
    f8=f11+f14;
    r3=dm(0x3,i3);
    r4=dm(0x4,i3);
    r5=dm(0x5,i3);
    f3=f3-f6;
    f4=f4-f7;
    f5=f5-f8;
    f3=f3*f3;
    f4=f4*f4;
    f5=f5*f5;
    f3=f3+f4;
    f3=f3+f5;
    comp(f3,f2);
    if lt jump _L209F0;
    r2=r3;
_L209F0:
    r1=r1+1;
    r0=0x10;
    comp(r1,r0);
    if ne jump _L209AE;
    r5=r2;
    r0=0x41500000;
    comp(f0,f5);
    if le jump _L20A14;
    call _L2029B;
    r1=dm(0x32181);
    f11=f1*f4;
    r0=0;
    comp(f0,f11);
    if ne jump _L209FF;
    r11=0x3f800000;
_L209FF:
    r0=0x3c23d70a;
    comp(f0,f11);
    if lt jump _L20A03;
    r11=r0;
_L20A03:
    r14=0;
_L20A04:
    btst r15 by r14;
    if not sz jump _L20A0E;
    r0=dm(0x14,i3);
    r0=r0+r14;
    i7=r0;
    r1=0;
    dm(i7,m0)=r1;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    jump _L20A0F;
_L20A0E:
    call _L20A17;
_L20A0F:
    r14=r14+1;
    r1=0x10;
    comp(r14,r1);
    if ne jump _L20A04;
    call _L20A6D;
_L20A14:
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;
_L20A17:
    r12=dm(0x10,i3);
    r13=dm(0x11,i3);
    i6=dm(0x13,i3);
    r0=r14;
    r1=0x10;
    m6=r0;
    r7=dm(m6,i6);
    r0=r0+r1;
    m6=r0;
    r6=dm(m6,i6);
    r0=r0+r1;
    m6=r0;
    r5=dm(m6,i6);
    r0=0;
    lcntr=0xc, do (pc,0x1) until lce;
    r0=r0+r14;
    r12=r12+r0;
    r13=r13+r0;
    i4=r12;
    i5=r13;
    i6=0x32184;
    lcntr=0xc, do (pc,0x4) until lce;
    r0=dm(i4,m1);
    r1=dm(i5,m1);
    f0=f0-f1;
    dm(i6,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r10=0;
    r9=dm(0x32180);
    r0=dm(0x14,i3);
    r0=r0+r14;
    i4=r0;
    r8=dm(i4,m0);
    r8=r8 and r8;
    if eq jump _L20A3D;
    r8=r8-1;
    jump _L20A3E;
_L20A3D:
    r8=dm(0x32182);
_L20A3E:
    dm(i4,m0)=r8;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x16,i3);
    r4=dm(0x18,i3);
    r2=0x80000000;
    r0=r0 and r0;
    if ne jump _L20A47;
    r2=0;
_L20A47:
    r0=lshift r9 by 0x5;
    r1=0x32300;
    r0=r0+r1;
    i7=r0;
    dm(i7,m1)=r14;
    r0=dm(0x12,i3);
    r0=r0 or r2;
    dm(i7,m1)=r0;
    dm(i7,m1)=r8;
    dm(i7,m1)=r4;
    dm(i7,m1)=r7;
    dm(i7,m1)=r6;
    dm(i7,0xe)=r5;
    r8=r8+1;
    i6=0x32184;
    i5=r13;
    lcntr=0xc, do (pc,0x5) until lce;
    r0=dm(i6,m1);
    r1=dm(i5,m1);
    f0=f0*f10;
    f0=f0+f1;
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r9=r9+1;
    r0=0x7f;
    r9=r9 and r0;
    r0=0;
    comp(f0,f11);
    if ge jump _L20A68;
    f10=f10+f11, r0=dm(m1,i3);
    comp(f10,f0);
    if lt jump _L20A47;
_L20A68:
    dm(0x32180)=r9;
    dm(i4,m0)=r8;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ==============================================================================
// _L20A6D  PARTICLE_TICK_ALL  (PM 0x20A6D)
// Tick all 128 particle slots in DM[0x32300..]. For each live slot apply
// one ang_y rotation by the stored angle and decrement the lifetime counter.
// ==============================================================================
_L20A6D:
    r0=dm(0x16,i3);
    call _L202C1;
    m7=0x20;
    r14=0;
    r7=0x1;
    i4=0x32301;
_L20A73:
    r15=dm(i4,m0);
    btst r15 by 0x1f;
    if sz jump _L20A89;
    r15=r7 and r15;
    dm(i4,0x13)=r15;
    r4=dm(0x3,i4);
    f8=f0*f4, r5=dm(0x6,i4);
    f12=f1*f5;
    f9=f1*f4, f8=f8-f12, r4=dm(0x4,i4);
    f13=f0*f5, dm(0x3,i4)=r8;
    f8=f0*f4, f9=f9+f13, r5=dm(0x7,i4);
    f12=f1*f5, dm(0x6,i4)=r9;
    f9=f1*f4, f8=f8-f12, r4=dm(0x5,i4);
    f13=f0*f5, dm(0x4,i4)=r8;
    f8=f0*f4, f9=f9+f13, r5=dm(0x8,i4);
    f12=f1*f5, dm(0x7,i4)=r9;
    f9=f1*f4, f8=f8-f12;
    f13=f0*f5, dm(0x5,i4)=r8;
    f9=f9+f13;
    dm(0x8,i4)=r9;
    r9=dm(i4,0xd);
    jump _L20A8A;
_L20A89:
    r9=dm(i4,m7);
_L20A8A:
    r14=r14+1;
    r15=0x80;
    comp(r14,r15);
    if ne jump _L20A73;
    rts;

// ----------------------------------------------------------------------------
// Fn_scrn_clip                 [official source label]   dispatch 0x7B  opcode 0x3D807B7B
//   in=?  out=?    PM 0x20A8F   screen clip test
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    i7=dm(0x3033f);
    call _L20173;
    call _L205D0 (db);
    r1=dm(m1,i3);
    r2=r10;
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    f8=f8*f1;
    f8=f8*f0;
    f9=f9*f2;
    f9=f9*f0;
    r15=0;
    r14=0x3dcccccc;
    comp(f10,f14);
    if gt jump _L20AA8;
    r15=0x1f;
    jump _L20AB8;
_L20AA8:
    r13=0xc3780000;
    comp(f8,f13);
    if gt jump _L20AAC;
    r15=bset r15 by 0;
_L20AAC:
    r13=0x43780000;
    comp(f8,f13);
    if lt jump _L20AB0;
    r15=bset r15 by 0x1;
_L20AB0:
    r13=0xc3400000;
    comp(f9,f13);
    if gt jump _L20AB4;
    r15=bset r15 by 0x2;
_L20AB4:
    r13=0x43400000;
    comp(f9,f13);
    if lt jump _L20AB8;
    r15=bset r15 by 0x3;
_L20AB8:
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_ziku_rot                  [official source label]   dispatch 0x79  opcode 0x3C807979
//   in=?  out=?    PM 0x20ABB   rotate about an arbitrary axis ("ziku" = axis)
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r15=dm(m0,i0);
    r0=0x31000;
    r15=r15+r0;
    i5=r15;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L202C1;
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r5=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r6=dm(m0,i0);
    r11=r1;
    r3=r0;
    r7=dm(m1,i3);
    f7=f7-f3;
    f8=f4*f4;
    f9=f5*f5;
    f10=f6*f6;
    f8=f8*f7;
    f9=f9*f7;
    f10=f10*f7;
    f8=f8+f3;
    f9=f9+f3;
    f10=f10+f3;
    dm(0,i5)=r8;
    dm(0x4,i5)=r9;
    dm(0x8,i5)=r10;
    f8=f5*f4;
    f8=f7*f8;
    f10=f11*f6;
    f9=f8-f10;
    f8=f8+f10;
    dm(0x1,i5)=r8;
    dm(0x3,i5)=r9;
    f8=f6*f4;
    f8=f8*f7;
    f10=f11*f5;
    f9=f8+f10;
    f8=f8-f10;
    dm(0x2,i5)=r8;
    dm(0x6,i5)=r9;
    f8=f6*f5;
    f8=f8*f7;
    f10=f11*f4;
    f9=f8-f10;
    f8=f8+f10;
    dm(0x5,i5)=r8;
    dm(0x7,i5)=r9;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ----------------------------------------------------------------------------
// Fn_put_poly                  [official source label]   dispatch 0x78  opcode 0x3C007878
//   in=8  out=2    PM 0x20AF1   submit a polygon to the GEO display list
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r10=dm(m0,i0);
    r0=lshift r10 by -2;
    if flag0_in jump (pc, 0);
    r11=dm(m0,i0);
    r1=0x1400000;
    if flag0_in jump (pc, 0);
    r12=dm(m0,i0);
    r2=0x5800b0b;
    if flag0_in jump (pc, 0);
    r13=dm(m0,i0);
    r0=r0+r1;
    if flag0_in jump (pc, 0);
    r14=dm(m0,i0);
    i6=r0;
    if flag0_in jump (pc, 0);
    r15=dm(m0,i0);
    dm(i6,m1)=r2;
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i7,m1);
    dm(i6,m1)=r0;
    if flag0_in jump (pc, 0);
    r10=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r9=dm(m0,i0);
    r2=0x800101;
    dm(i6,m1)=r2;
    r7=lshift r15 by -14;
    dm(i6,m1)=r12;
    r6=0xffff;
    r15=r15 and r6;
    r11=r11 and r11;
    if eq jump _L20B15;
    r13=r13+r7;
    r10=r10+r15;
_L20B15:
    dm(i6,m1)=r13;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r10;
    r9=r9+r15;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r9;
    dm(i6,m1)=r14;
    rts (db);
    r8=-1;
    dm(i6,m1)=r15;

// ----------------------------------------------------------------------------
// Fn_parts_oidasi              [official source label]   dispatch 0x77  opcode 0x3B807777
//   in=4  out=9    PM 0x20B1F   part push-out ("oidasi") collision resolve; [0..1] = position correction deltas
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r8=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r9=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r10=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r11=dm(m0,i0);
    dm(0x1b,i3)=r11;
    r0=0;
    r1=-1;
    dm(0x18,i3)=r0;
    dm(0x19,i3)=r0;
    dm(0x13,i3)=r0;
    dm(0x14,i3)=r0;
    dm(0x15,i3)=r0;
    dm(0x16,i3)=r0;
    dm(0x1a,i3)=r1;
    dm(0x1c,i3)=r0;
    dm(0x1e,i3)=r0;
    dm(0x1f,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L20B80 (db);
    i4=0x1403e80;
    i5=0x30600;
    r0=dm(0x12,i3);
    dm(0x13,i3)=r0;
    r1=0;
    call _L20D98;
    dm(0x15,i3)=r14;
    r0=dm(0x1f,i3);
    r0=r0 and r0;
    if eq jump _L20B48;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r1=0;
    dm(0x1a,i3)=r1;
    r0=dm(0x19,i3);
    call _L20B79;
    dm(0x18,i3)=r2;
_L20B48:
    call _L20B80 (db);
    i4=0x1407e80;
    i5=0x30700;
    r0=dm(0x12,i3);
    dm(0x14,i3)=r0;
    r1=0x1;
    call _L20D98;
    dm(0x16,i3)=r14;
    r0=dm(0x1f,i3);
    r0=r0 and r0;
    if eq jump _L20B5B;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r1=0x1;
    dm(0x1a,i3)=r1;
    r0=dm(0x19,i3);
    call _L20B79;
    dm(0x18,i3)=r2;
    jump _L20B5B;
_L20B5B:
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r15=dm(0x1c,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r15;
    r15=dm(0x1e,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r15;
    r1=dm(0x1a,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r1;
    r0=dm(0x19,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    r2=dm(0x18,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r2;
    r0=dm(0x13,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    r0=dm(0x15,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    r0=dm(0x14,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    r0=dm(0x16,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ==============================================================================
// _L20B79  GET_BONE_TABLE_PTR  (PM 0x20B79)  helper
// Return DM pointer into player bone table.
// player0 -> base 0x306A0, player1 -> base 0x307A0.
// Entry: r1 bit0=player, r0=bone index. Exit: r2=DM address.
// ==============================================================================
_L20B79:
    i6=0x306a0;
    btst r1 by 0;
    if sz jump _L20B7D;
    i6=0x307a0;

// -- get_bone_table_ptr: player 1 path --
_L20B7D:
    rts (db);
    m6=r0;
    r2=dm(m6,i6);

// ==============================================================================
// _L20B80  HIT_SPHERE_TRACE  (PM 0x20B80)  helper
// Scan static sphere sequence at i5 for intersection with moving sphere.
// Entry: i4=moving sphere bone ptr, i5=static sphere list, r8/r9/r10=centre.
// ==============================================================================
_L20B80:
    r0=0;
    dm(0x1f,i3)=r0;
    dm(0x12,i3)=r0;
    r0=dm(0x27,i4);
    r1=dm(0x28,i4);
    r2=dm(0x29,i4);
    f0=f0-f8;
    call _L2034C (db);
    f1=f1-f9;
    f2=f2-f10;
    r3=0x40400000;
    comp(f0,f3);
    if gt jump _L20BBA;
    r0=0;
    dm(0x17,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    lcntr=0x20, do (pc,0x29) until lce;
    r0=dm(i4,m1);
    f0=f0-f8, r1=dm(i4,m1);
    f1=f1-f9, r2=dm(i4,m1);
    f2=f2-f10, r6=dm(i5,m1);
    r6=r6 and r6;
    if eq jump _L20BB5;
    r5=r0;
    call _L2034C (db);
    r7=r2;
    r3=dm(0x1b,i3);
    f6=f6+f3, r1=dm(m1,i3);
    comp(f0,f6);
    if gt jump _L20BB5;
    r4=r0;
    r14=r6;
    f4=recips f14, r2=r4;
    f14=f4*f14;
    f2=f2*f4, f4=f11-f14;
    f14=f4*f14;
    f2=f2*f4, f4=f11-f14;
    f14=f4*f14;
    f2=f2*f4, f4=f11-f14;
    f0=f2*f4;
    f0=f1-f0;
    f5=f5*f0, r1=dm(0x1c,i3);
    f7=f7*f0, r2=dm(0x1e,i3);
    f1=f1+f5;
    f2=f2+f7, dm(0x1c,i3)=r1;
    dm(0x1e,i3)=r2;
    dm(0x1f,i3)=r0;
    r15=dm(0x17,i3);
    dm(0x19,i3)=r15;
    r0=dm(0x12,i3);
    r0=bset r0 by r15;
    dm(0x12,i3)=r0;
_L20BB5:
    r15=dm(0x17,i3);
    r15=r15+1;
    dm(0x17,i3)=r15;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
_L20BBA:
    nop;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_area_coli                 [official source label]   dispatch 0x70  opcode 0x38007070
//   in=1  out=0    PM 0x20BBE   area collision test
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x30801)=r0;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x30800)=r0;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x30802)=r0;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x30804)=r0;
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    dm(0x1e,i3)=r1;
    r1=bclr r1 by 0x1f;
    dm(0x307f2)=r1;
    r3=0x1407e80;
    r15=0x30700;
    dm(0x1f,i3)=r15;
    r1=r1 and r1;
    if ne jump _L20BDB;
    r3=0x1403e80;
    r15=0x30600;
    dm(0x1f,i3)=r15;
    i6=0x30817;
    lcntr=0x10, do (pc,0x2) until lce;
    r0=0;
    dm(i6,m1)=r0;
_L20BDB:
    dm(0x30803)=r3;
    i6=0x30805;
    r0=0;
    lcntr=0x12, do (pc,0x1) until lce;
    dm(i6,m1)=r0;
    i6=0x30813;
    r0=0x42c80000;
    lcntr=0x4, do (pc,0x1) until lce;
    dm(i6,m1)=r0;
    r11=0;
    dm(0x3,i3)=r11;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
_L20BE8:
    r1=r11+r11;
    r1=r1+r11;
    r4=r3+r1;
    i6=r4;
    r12=dm(m0,i6);
    r13=dm(m1,i6);
    r14=dm(m2,i6);
    i6=dm(0x1f,i3);
    m6=r11;
    r15=dm(m6,i6);
    r15=r15 and r15;
    if eq jump _L20C53;
    f0=f13+f15;
    r4=dm(0x3080a);
    comp(f0,f4);
    if le jump _L20BF9;
    dm(0x3080a)=r0;
_L20BF9:
    f0=f13-f15;
    r4=dm(0x30804);
    comp(f4,f0);
    if le jump _L20C53;
    r0=dm(0x3,i3);
    r0=bset r0 by r11;
    dm(0x3,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r2=0x1;
    r4=0x3d4ccccc;
    f0=f13-f15;
    comp(f0,f4);
    if gt jump _L20C0A;
    r5=dm(0x30805);
    r5=bset r5 by r11;
    dm(0x30805)=r5;
_L20C0A:
    r4=0xbdcccccc;
    f0=f13+f15;
    comp(f0,f4);
    if gt jump _L20C11;
    r5=dm(0x30806);
    r5=bset r5 by r11;
    dm(0x30806)=r5;
_L20C11:
    r6=dm(0x30800);
    r4=0x3d4ccccc;
    f4=f4+f6;
    f0=f13-f15;
    comp(f0,f4);
    if gt jump _L20C1A;
    r5=dm(0x30807);
    r5=bset r5 by r11;
    dm(0x30807)=r5;
_L20C1A:
    r6=dm(0x30801);
    r4=0x3d4ccccc;
    f4=f4+f6;
    f0=f13-f15;
    comp(f0,f4);
    if gt jump _L20C23;
    r5=dm(0x30808);
    r5=bset r5 by r11;
    dm(0x30808)=r5;
_L20C23:
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r10=0;
    r5=dm(0x30802);
_L20C27:
    r0=r12;
    btst r10 by 0x1;
    if not sz r0=r14;
    f7=f0+f15;
    f2=f5-f7;
    btst r10 by 0;
    if sz jump _L20C30;
    f7=f0-f15;
    f2=f5+f7;
_L20C30:
    r1=lshift r10 by 0x1f;
    r1=r1 xor r7;
    btst r1 by 0x1f;
    if not sz jump _L20C47;
    f4=abs f7;
    comp(f5,f4);
    if gt jump _L20C47;
    if lt jump _L20C3A;
    r4=0x3a83126e;
    jump _L20C40;
_L20C3A:
    r0=dm(0x30809);
    r0=bset r0 by r11;
    dm(0x30809)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    f4=f4-f5;
_L20C40:
    i6=0x3080b;
    m6=r10;
    r0=dm(m6,i6);
    comp(f4,f0);
    if lt jump _L20C4F;
    dm(m6,i6)=r4;
    jump _L20C4F;
_L20C47:
    i6=0x30813;
    m6=r10;
    r0=dm(m6,i6);
    comp(f2,f0);
    if ge jump _L20C4F;
    dm(m6,i6)=r2;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
_L20C4F:
    r10=r10+1;
    r0=0x4;
    r0=r0-r10;
    if ne jump _L20C27;
_L20C53:
    r11=r11+1;
    r0=0x20;
    r0=r0-r11;
    if ne jump _L20BE8;
    r0=dm(0x30809);
    r1=dm(0x3,i3);
    r2=r1 and r0;
    r2=r2-r1;
    if ne jump _L20C65;
    r0=dm(0x1e,i3);
    btst r0 by 0x1f;
    if sz jump _L20C65;
    dm(0x3080b)=r2;
    dm(0x3080c)=r2;
    dm(0x3080d)=r2;
    dm(0x3080e)=r2;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
_L20C65:
    i6=0x30813;
    i7=0x3080f;
    m6=-1;
    r8=0x42c80000;
    r9=dm(0x30802);
    f9=f9+f9;
    r14=0x3a83126e;
    r15=0;
    r10=0;
    r7=0x4;
_L20C6F:
    r3=dm(m0,i6);
    comp(f3,f8);
    if eq jump _L20C7C;
    r4=dm(m1,i6);
    btst r10 by 0;
    if sz jump _L20C76;
    r4=dm(m6,i6);
_L20C76:
    f5=f9-f4;
    f13=f15-f5;
    if eq r5=r14;
    dm(m0,i7)=r5;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
_L20C7C:
    r5=dm(i6,m1);
    r5=dm(i7,m1);
    r10=r10+1;
    r5=r10-r7;
    if ne jump _L20C6F;
    i6=0x3080f;
    lcntr=0x2, do (pc,0x11) until lce;
    r4=dm(m0,i6);
    r5=dm(m1,i6);
    r9=0;
    btst r4 by 0x1f;
    if not sz r4=r9;
    btst r5 by 0x1f;
    if not sz r5=r9;
    comp(f4,f5);
    if gt jump _L20C8E;
    r5=r9;
    jump _L20C8F;
_L20C8E:
    r4=r9;
_L20C8F:
    dm(m0,i6)=r4;
    dm(m1,i6)=r5;
    r5=dm(i6,m2);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r4=dm(0x3080f);
    r5=dm(0x30810);
    r7=dm(0x30811);
    r8=dm(0x30812);
    f6=f4+f5;
    f9=f7+f8;
    comp(f6,f9);
    if lt jump _L20C9F;
    r4=0;
    r5=0;
    jump _L20CA1;
_L20C9F:
    r7=0;
    r8=0;
_L20CA1:
    dm(0x3080f)=r4;
    dm(0x30810)=r5;
    dm(0x30811)=r7;
    dm(0x30812)=r8;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    i6=0x30805;
    lcntr=0x12, do (pc,0x5) until lce;
    r0=dm(i6,m1);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    nop;
    nop;
    r0=dm(0x30805);
    call _L20D97;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r14;
    r0=dm(0x30809);
    call _L20D97;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r14;
    r0=dm(0x30807);
    call _L20D97;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r14;
    r0=dm(0x30808);
    call _L20D97;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r14;
    rts;

// ----------------------------------------------------------------------------
// Fn_kage_flag                 [official source label]   dispatch 0x75  opcode 0x3A807575
//   in=6  out=0    PM 0x20CBF   shadow ("kage") flags
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r7=0x1403e80;
    i6=0x306e0;
    r0=r0 and r0;
    if eq jump _L20CC7;
    r7=0x1407e80;
    i6=0x307e0;
_L20CC7:
    if flag0_in jump (pc, 0);
    r15=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r13=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r14=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r11=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r12=dm(m0,i0);
    r8=0x3;
    r9=0;
    r10=0;
    r2=0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    lcntr=0x10, do (pc,0x2d) until lce;
    r0=dm(i6,m1);
    r1=r0+r0;
    r0=r1+r0;
    r0=r0+r7;
    i7=r0;
    r4=dm(m0,i7);
    r5=dm(m1,i7);
    r6=dm(m2,i7);
    f3=f13*f5;
    f4=f3+f4;
    f3=f14*f5;
    f6=f3+f6;
    r15=r15 and r15;
    if eq jump _L20CF7;
    dm(0x10,i3)=r15;
    dm(0x11,i3)=r11;
    dm(0x12,i3)=r4;
    dm(0x13,i3)=r2;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    f0=f4*f4;
    f1=f6*f6;
    f0=f0+f1;
    call _L202AE;
    r15=dm(0x10,i3);
    r11=dm(0x11,i3);
    r4=dm(0x12,i3);
    r2=dm(0x13,i3);
    jump _L20CFB (db);
    r1=0x3f3504e6;
    f4=f1*f0;
_L20CF7:
    r4=bclr r4 by 0x1f;
    r6=bclr r6 by 0x1f;
    comp(f4,f6);
    if lt r4=r6;
_L20CFB:
    btst r5 by 0x1f;
    if not sz jump _L20D01;
    comp(f4,f11);
    if gt jump _L20D01;
    r9=bset r9 by r2;
    jump _L20D04;
_L20D01:
    comp(f4,f12);
    if lt jump _L20D04;
    r10=bset r10 by r2;
_L20D04:
    r2=r2+1;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r9;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r10;
    rts;

// ----------------------------------------------------------------------------
// Fn_kage_poly                 [official source label]   dispatch 0x74  opcode 0x3A007474
//   in=5  out=0    PM 0x20D0A   shadow ("kage") polygon
// ----------------------------------------------------------------------------
    call _L20375;
    call _L204D6;
    if flag0_in jump (pc, 0);
    r15=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    btst r15 by 0x2;
    if sz jump _L20D17;
    call _L20182;
_L20D17:
    btst r15 by 0x1;
    if not sz jump _L20D1D;
    btst r15 by 0;
    if sz jump _L20D1E;
    call _L20516;
    jump _L20D1E;
_L20D1D:
    call _L20529;
_L20D1E:
    jump _L2056E;

// ----------------------------------------------------------------------------
// Fn_kage_mat                  [official source label]   dispatch 0x73  opcode 0x39807373
//   in=2  out=0    PM 0x20D1F   shadow ("kage") matrix
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x14,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L202C1;
    f3=recips f1;
    r7=0x3f800000;
    f15=f3*f1;
    r11=0x40000000;
    f7=f3*f7, f3=f11-f15;
    f15=f3*f15;
    f7=f3*f7, f3=f11-f15;
    f15=f3*f15;
    f7=f3*f7, f3=f11-f15;
    f1=f3*f7;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    f2=f1*f0;
    r4=dm(0x30800);
    f5=-f4;
    f5=f5*f2;
    if flag0_in jump (pc, 0);
    r15=dm(m0,i0);
    r6=bset r15 by 0xf;
    r7=bclr r15 by 0xf;
    btst r15 by 0xf;
    if sz r7=r6;
    r6=-r7;
    dm(0x10,i3)=r7;
    dm(0x11,i3)=r6;
    dm(0x12,i3)=r1;
    dm(0x13,i3)=r5;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L20375;
    r0=dm(0x10,i3);
    call _L203D3;
    r0=dm(m1,i3);
    r1=dm(m1,i3);
    r2=dm(0x12,i3);
    call _L203C9;
    r0=dm(0x11,i3);
    call _L203D3;
    r0=0x1;
    call _L2053E;
    call _L20389;
    call _L20375;
    r0=dm(0x10,i3);
    call _L203D3;
    r0=0;
    r1=dm(0x30800);
    r2=dm(0x13,i3);
    call _L20182;
    r0=dm(m1,i3);
    r1=dm(m1,i3);
    r2=dm(0x12,i3);
    call _L203C9;
    r0=dm(0x11,i3);
    call _L203D3;
    r0=0x2;
    call _L2053E;
    call _L20389;
    call _L20375;
    call _L2039B;
    r0=dm(0x10,i3);
    call _L203D3;
    r0=dm(m1,i3);
    r1=0;
    r2=dm(m1,i3);
    call _L203C9;
    r0=dm(0x14,i3);
    r1=0x4000;
    r0=r0-r1;
    call _L203CE;
    r0=dm(0x11,i3);
    call _L203D3;
    r0=0;
    call _L2053E;
    jump _L20389;

// ----------------------------------------------------------------------------
// Fn_outside_ball              [official source label]   dispatch 0x72  opcode 0x39007272
//   in=3  out=0    PM 0x20D6F   outside-of-ball test
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r14=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r15=dm(m0,i0);
    r3=0x1403e80;
    r0=r0 and r0;
    if eq jump _L20D79;
    r3=0x1407e80;
_L20D79:
    i6=r3;
    m6=0x3;
    r10=0;
    r11=0;
    r9=dm(0x30802);
    lcntr=0x20, do (pc,0xc) until lce;
    r4=dm(i6,m1);
    f4=f4+f14, r5=dm(i6,m1);
    r6=dm(i6,m1);
    f6=f6+f15;
    r4=bclr r4 by 0x1f;
    r6=bclr r6 by 0x1f;
    comp(f4,f9);
    if gt jump _L20D89;
    comp(f6,f9);
    if lt jump _L20D8A;
_L20D89:
    r11=r11+1;
_L20D8A:
    nop;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r11;
    rts;

// ----------------------------------------------------------------------------
// Fn_ball_to_unit              [official source label]   dispatch 0x71  opcode 0x38807171
//   in=?  out=?    PM 0x20D8E   convert a collision ball into the unit-matrix frame
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    dm(0x307f2)=r1;
    call _L20D97;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r14;
    rts;

// ==============================================================================
// _L20D97  REMAP_BUTTONS  (PM 0x20D97)  helper
// Remap raw input bitmask (r0) through player button remap table.
// Player select from DM[0x307F2]. player0->DM[0x306A0], player1->DM[0x307A0].
// Exit: r14=remapped button bitmask.
// ==============================================================================
_L20D97:
    r1=dm(0x307f2);

// -- remap_buttons: player index taken from r1 directly (not DM[0x307F2]) --
_L20D98:
    i6=0x306a0;
    btst r1 by 0;
    if sz jump _L20D9C;
    i6=0x307a0;

// -- remap_buttons: player 1 table address set --
_L20D9C:
    r14=0;
    r11=0;
    r13=0x20;

// -- remap_buttons: per-bit mapping loop --
_L20D9F:
    btst r0 by r11;
    if sz jump _L20DA4;
    m6=r11;
    r12=dm(m6,i6);
    r14=bset r14 by r12;

// -- remap_buttons: bit not set, skip --
_L20DA4:
    r11=r11+1;
    r15=r11-r13;
    if ne jump _L20D9F;
    rts;

// ----------------------------------------------------------------------------
// Fn_coli_set_ball_adrs        [official source label]   dispatch 0x38  opcode 0x1C003838
//   in=1  out=0    PM 0x20DA8   point the collision engine at a sphere ("ball") table
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r9=dm(m0,i0);
    r1=0x1;
    r0=0x1403e80;
    comp(r9,r1);
    if ne jump _L20DAF;
    r0=0x1407e80;
_L20DAF:
    dm(0x3033e)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_coli_copy_unit_matrix     [official source label]   dispatch 0x7F  opcode 0x3F807F7F
//   in=1  out=0    PM 0x20DB3   copy the unit matrix into the collision buffer
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r9=dm(m0,i0);
    r1=0x1;
    i6=0x30420;
    i7=0x32000;
    comp(r9,r1);
    if ne jump _L20DBC;
    i6=0x304e0;
    i7=0x320c0;
_L20DBC:
    lcntr=0xc0, do (pc,0x2) until lce;
    r0=dm(i6,m1);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts;

// ----------------------------------------------------------------------------
// Fn_coli_point_trans          [official source label]   dispatch 0x39  opcode 0x1C803939
//   in=4  out=0    PM 0x20DC2   collision-space point transform
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    i7=dm(0x3033f);
    call _L20173;
    if flag0_in jump (pc, 0);
    r3=dm(m0,i0);
    r0=dm(0x3033e);
    r0=r0+r3;
    r1=0x60;
    r1=r1+r0;
    i7=r0;
    i6=r1;
    r0=dm(i7,m0);
    dm(i7,m1)=r8;
    nop;
    dm(i6,m1)=r0;
    r0=dm(i7,m0);
    dm(i7,m1)=r9;
    nop;
    dm(i6,m1)=r0;
    r0=dm(i7,m0);
    dm(i7,m1)=r10;
    rts (db);
    nop;
    dm(i6,m1)=r0;

// ----------------------------------------------------------------------------
// Fn_area_table_gen            [official source label]   dispatch 0x3A  opcode 0x1D003A3A
//   in=4  out=0    PM 0x20DDF   build the area table
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x11,i3)=r0;
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    dm(0x12,i3)=r1;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x3041a)=r0;
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    dm(0x3041b)=r1;
    r0=0;
    dm(0x10,i3)=r0;
    r0=-1;
    i6=0x1403e20;
    lcntr=0x20, do (pc,0x2) until lce;
    dm(i6,m1)=r0;
    nop;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
_L20DF4:
    r0=0x1;
    dm(0x5,i3)=r0;
    i6=0x30340;
    r0=0;
    lcntr=0x80, do (pc,0x1) until lce;
    dm(i6,m1)=r0;
    r0=0x1403f40;
    r1=dm(0x10,i3);
    r0=r0+r1;
    dm(0x3,i3)=r0;
    r0=0x30600;
    dm(0x6,i3)=r0;
    r12=0;
    m6=0x60;
    lcntr=0x20, do (pc,0x4c) until lce;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    i7=dm(0x3,i3);
    r0=dm(i7,m0);
    r4=i7;
    r1=dm(m6,i7);
    r3=0x3;
    r4=r4+r3;
    dm(0x3,i3)=r4;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    f4=f1-f0;
    if ge jump _L20E13;
    r15=r0;
    r0=r1;
    r1=r15;
_L20E13:
    i7=dm(0x6,i3);
    r8=dm(i7,m1);
    r15=i7;
    dm(0x6,i3)=r15;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r8=r8 and r8;
    if eq jump _L20E4B;
    r14=dm(0x11,i3);
    r13=lshift r14 by -1;
    dm(0x11,i3)=r13;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    btst r14 by 0;
    if sz jump _L20E28;
    r14=dm(0x3041a);
    r15=0x4;
    r15=r15-r14;
    if eq jump _L20E28;
    r14=dm(0x306f0);
    f8=f8*f14;
_L20E28:
    f0=f0-f8;
    f1=f1+f8;
    r15=0x41000000;
    r14=0x42000000;
    r13=0x3f000000;
    f8=f0*f15;
    f8=f8+f14;
    f8=f8-f13;
    r2=fix f8;
    r3=0x3f;
    r2=r2 and r3;
    r3=dm(0x5,i3);
    r4=0x30340;
    r11=r4+r2;
    i6=r11;
    r5=dm(i6,m0);
    r5=r5 or r3;
    dm(i6,m0)=r5;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    f8=f1*f15;
    f8=f8+f14;
    f8=f8-f13;
    r2=fix f8;
    r3=0x3f;
    r2=r2 and r3;
    r3=dm(0x5,i3);
    r4=0x30380;
    r11=r4+r2;
    i6=r11;
    r5=dm(i6,m0);
    r5=r5 or r3;
    dm(i6,m0)=r5;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
_L20E4B:
    r12=r12+1;
    r0=dm(0x5,i3);
    r0=lshift r0 by 0x1;
    dm(0x5,i3)=r0;
    m6=-1;
    m7=-2;
    i7=0x30340;
    r0=0;
    r1=dm(i7,m1);
    lcntr=0x3f, do (pc,0x5) until lce;
    r0=r1 or r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r1=dm(i7,m6);
    dm(i7,m2)=r0;
    i7=0x303bf;
    r0=0;
    r1=dm(i7,m6);
    lcntr=0x3f, do (pc,0x5) until lce;
    r0=r1 or r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r1=dm(i7,m1);
    dm(i7,m7)=r0;
    r0=0x1407f40;
    r1=dm(0x10,i3);
    r0=r0+r1;
    dm(0x3,i3)=r0;
    r2=0;
    dm(0x8,i3)=r2;
    r0=0x30700;
    dm(0x6,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r12=0;
    m6=0x60;
    m7=0x3;
    lcntr=0x20, do (pc,0x53) until lce;
    i7=dm(0x3,i3);
    r0=dm(i7,m0);
    r1=dm(m6,i7);
    r13=dm(i7,m7);
    r13=i7;
    dm(0x3,i3)=r13;
    f4=f1-f0;
    if ge jump _L20E7C;
    r15=r0;
    r0=r1;
    r1=r15;
_L20E7C:
    i7=dm(0x6,i3);
    r8=dm(i7,m1);
    r15=i7;
    dm(0x6,i3)=r15;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r8=r8 and r8;
    if eq jump _L20ED0;
    r14=dm(0x12,i3);
    r13=lshift r14 by -1;
    dm(0x12,i3)=r13;
    btst r14 by 0;
    if sz jump _L20E8F;
    r14=dm(0x3041b);
    r15=0x4;
    r15=r15-r14;
    if eq jump _L20E8F;
    r14=dm(0x307f0);
    f8=f8*f14;
_L20E8F:
    f0=f0-f8;
    f1=f1+f8;
    r15=0x41000000;
    r14=0x42000000;
    r13=0x3f000000;
    r12=0x42800000;
    f8=f0*f15;
    f8=f8+f14;
    if lt jump _L20ED0;
    f7=f8-f12;
    if ge jump _L20ED0;
    f8=f8-f13;
    r2=fix f8;
    r3=0x3f;
    r2=r2 and r3;
    r4=0x30380;
    r11=r4+r2;
    i6=r11;
    r5=dm(i6,m0);
    dm(0x5,i3)=r5;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    f8=f1*f15;
    f8=f8+f14;
    if lt jump _L20ED0;
    f7=f8-f12;
    if ge jump _L20ED0;
    f8=f8-f13;
    r2=fix f8;
    r3=0x3f;
    r2=r2 and r3;
    r4=0x30340;
    r11=r4+r2;
    i6=r11;
    r5=dm(i6,m0);
    r4=dm(0x5,i3);
    r4=r4 and r5;
    r6=dm(0x8,i3);
_L20EB5:
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r7=0x1403e20;
    r15=r7+r6;
    i6=r15;
    r3=dm(i6,m0);
    r3=r3 and r4;
    dm(i6,m0)=r3;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r6=dm(0x8,i3);
    r6=r6+1;
    dm(0x8,i3)=r6;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x10,i3);
    r0=r0+1;
    dm(0x10,i3)=r0;
    r1=0x3;
    comp(r0,r1);
    if ne jump _L20DF4;
    i6=0x1403d80;
    r0=0;
    lcntr=0x10, do (pc,0x2) until lce;
    nop;
    dm(i6,m1)=r0;
    rts;
_L20ED0:
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    jump _L20EB5 (db);
    r4=0;
    r6=dm(0x8,i3);

// ----------------------------------------------------------------------------
// Fn_calc_coli_flag            [official source label]   dispatch 0x3B  opcode 0x1D803B3B
//   in=7  out=0    PM 0x20ED5   compute collision flags
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x1c,i3)=r0;
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    dm(0x17,i3)=r1;
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    dm(0x18,i3)=r2;
    if flag0_in jump (pc, 0);
    r3=dm(m0,i0);
    dm(0x19,i3)=r3;
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    dm(0x1a,i3)=r4;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x30417)=r0;
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    dm(0x30418)=r1;
    r5=0;
    dm(0x14,i3)=r5;
    dm(0x15,i3)=r5;
    dm(0x1e,i3)=r5;
    dm(0x1d,i3)=r5;
    r6=0x1403e20;
    dm(0x12,i3)=r6;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    i6=0x1403f40;
    i7=0x30340;
    lcntr=0x60, do (pc,0x2) until lce;
    r10=dm(i6,m1);
    dm(i7,m1)=r10;
    i6=0x1403fa0;
    i7=0x303a0;
    lcntr=0x60, do (pc,0x2) until lce;
    r10=dm(i6,m1);
    dm(i7,m1)=r10;
    r10=0x1;
    dm(0x11,i3)=r10;
    r15=0x20;
_L20F00:
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r11=-1;
    i7=dm(0x12,i3);
    r10=dm(i7,m0);
    dm(0x13,i3)=r10;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r10=r10 and r11;
    if eq jump _L2100D;
    i6=0x30720;
    m7=r15;
    r10=dm(m7,i6);
    r10=r10 and r10;
    if eq jump _L2100D;
    r0=dm(0x18,i3);
    r1=dm(0x11,i3);
    r1=r0 and r1;
    if eq jump _L20F19;
    r0=dm(0x3041b);
    r1=0x4;
    r0=r0-r1;
    if eq jump _L20F19;
    r0=dm(0x307f0);
    f10=f10*f0;
_L20F19:
    dm(0x30416)=r10;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    i6=0x30741;
    r5=dm(m7,i6);
    r10=0x1407f40;
    r13=r10+r5;
    i6=r13;
    i7=0x30410;
    r11=dm(i6,m1);
    dm(i7,m1)=r11;
    r11=dm(i6,m1);
    dm(i7,m1)=r11;
    r11=dm(i6,m1);
    dm(i7,m1)=r11;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r10=0x1407fa0;
    r13=r10+r5;
    i6=r13;
    r11=dm(i6,m1);
    dm(i7,m1)=r11;
    r11=dm(i6,m1);
    dm(i7,m1)=r11;
    r11=dm(i6,m1);
    dm(i7,m1)=r11;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r2=dm(0x18,i3);
    r12=dm(0x11,i3);
    r11=-1;
    r2=r2 and r12;
    if ne jump _L20F3B;
    r11=dm(0x17,i3);
_L20F3B:
    dm(0x16,i3)=r11;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x11,i3);
    r11=dm(0x30418);
    r11=r11 and r0;
    if eq jump _L2100D;
    r10=0x1;
    dm(0x10,i3)=r10;
    r9=dm(0x13,i3);
    r8=r10;
    r14=0x20;
_L20F47:
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x30417);
    r0=r0 and r8;
    if eq jump _L20F4E;
    r7=r8 and r9;
    if ne jump _L20F58;
_L20F4E:
    r8=dm(0x10,i3);
    r8=lshift r8 by 0x1;
    dm(0x10,i3)=r8;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r13=0x1;
    comp(r13,r14);
    if eq jump _L2100D;
    r14=r14-1;
    jump _L20F47;
_L20F58:
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    i6=0x30620;
    m6=r14;
    r4=dm(m6,i6);
    r4=r4 and r4;
    if eq jump _L21002;
    r13=dm(0x14,i3);
    r13=r13+1;
    dm(0x14,i3)=r13;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x17,i3);
    r1=dm(0x10,i3);
    r1=r0 and r1;
    if eq jump _L20F6E;
    r0=dm(0x3041a);
    r1=0x4;
    r0=r0-r1;
    if eq jump _L20F6E;
    r0=dm(0x306f0);
    f4=f4*f0;
_L20F6E:
    dm(0x1b,i3)=r4;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    i6=0x30662;
    i6=dm(m6,i6);
    m7=0x60;
    r0=dm(m0,i6);
    r1=dm(m1,i6);
    r2=dm(m2,i6);
    r4=dm(0x30410);
    f8=f4-f0;
    r5=dm(0x30411);
    f9=f5-f1;
    r6=dm(0x30412);
    f10=f6-f2, dm(0x6,i3)=r8;
    dm(0x7,i3)=r9;
    dm(0x8,i3)=r10;
    dm(0x30406)=r8;
    dm(0x30407)=r9;
    dm(0x30408)=r10;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r13=dm(0x16,i3);
    r12=dm(0x10,i3);
    r13=r12 and r13;
    if ne jump _L2102F;
    f8=f8*f8;
    f9=f9*f9;
    f10=f10*f10;
    f8=f8+f9;
    f8=f8+f10;
_L20F8D:
    pm(0x21f00)=r8;
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    r0=dm(0x30416);
    r4=dm(0x1b,i3);
    f0=f0+f4;
    r6=r8;
    f0=f0*f0;
    pm(0x21f02)=r0;
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    f6=f6-f0;
    if ge jump _L20FFB;
    r6=dm(0x15,i3);
    r6=r6+1;
    dm(0x15,i3)=r6;
    dm(0x307f3)=r14;
    dm(0x307f4)=r15;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r5=dm(0x1c,i3);
    r4=0x4;
    r3=r4-r5;
    if eq jump _L20FA9;
    r4=0x5;
    r3=r4-r5;
    if eq jump _L20FBF;
    jump _L20FD5;
_L20FA9:
    r3=pm(0x21f02);
    r0=dm(0x6,i3);
    r4=dm(0x30406);
    f0=f0*f4, r1=dm(0x8,i3);
    r5=dm(0x30408);
    f1=f1*f5;
    f3=f3-f0;
    f3=f3-f1;
    r0=r3;
    r8=r15;
    r9=r14;
    call _L202AE;
    r15=r8;
    r14=r9;
    r4=dm(0x7,i3);
    f0=f0-f4, r5=dm(0x1d,i3);
    f1=f5-f0;
    if ge jump _L20FBE;
    dm(0x1d,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
_L20FBE:
    jump _L21002;
_L20FBF:
    r3=pm(0x21f02);
    r0=dm(0x6,i3);
    r4=dm(0x30406);
    f0=f0*f4, r1=dm(0x8,i3);
    r5=dm(0x30408);
    f1=f1*f5;
    f3=f3-f0;
    f3=f3-f1;
    r0=r3;
    r8=r15;
    r9=r14;
    call _L202AE;
    r15=r8;
    r14=r9;
    r4=dm(0x7,i3);
    f0=f0+f4, r5=dm(0x1d,i3);
    f1=f5-f0;
    if ge jump _L20FD4;
    dm(0x1d,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
_L20FD4:
    jump _L21002;
_L20FD5:
    r4=dm(0x16,i3);
    r3=dm(0x10,i3);
    r2=r4 and r3;
    if ne jump _L20FFA;
    r0=pm(0x21f00);
    r8=r15;
    r9=r14;
    call _L202AE;
    r15=r8;
    r14=r9;
    r4=dm(0x30416);
    r5=dm(0x1b,i3);
    f4=f4+f5;
    f0=f4-f0;
    pm(0x21f01)=r0;
    pm(0x21f18)=r15;
    pm(0x21f18)=r15;
    r0=dm(m1,i3);
    r4=dm(0x19,i3);
    r5=dm(0x10,i3);
    r3=r4 and r5;
    if eq jump _L20FF0;
    r4=dm(0x1a,i3);
    r5=dm(0x11,i3);
    r3=r4 and r5;
    if eq jump _L20FF0;
    r0=0;
_L20FF0:
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r1=pm(0x21f01);
    f0=f0*f1;
    r2=dm(0x1e,i3);
    f3=f0-f2;
    if lt jump _L20FFA;
    dm(0x1e,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
_L20FFA:
    jump _L21002;
_L20FFB:
    r5=dm(0x10,i3);
    r5= not r5;
    r4=dm(0x13,i3);
    r4=r5 and r4;
    dm(0x13,i3)=r4;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
_L21002:
    r8=dm(0x10,i3);
    r8=lshift r8 by 0x1;
    r9=dm(0x13,i3);
    dm(0x10,i3)=r8;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r13=0x1;
    comp(r14,r13);
    if eq jump _L2100D;
    r14=r14-1;
    jump _L20F47;
_L2100D:
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r6=dm(0x12,i3);
    r5=0x4000;
    r13=r6+r5;
    i6=r13;
    r0=dm(0x13,i3);
    dm(i6,m0)=r0;
    r6=r6+1;
    dm(0x12,i3)=r6;
    r5=dm(0x11,i3);
    r5=lshift r5 by 0x1;
    dm(0x11,i3)=r5;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r13=0x1;
    comp(r15,r13);
    if eq jump _L21021;
    r15=r15-1;
    jump _L20F00;
_L21021:
    call _L21083;
    r0=dm(0x14,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    r0=dm(0x15,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    r0=dm(0x1e,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    r0=dm(0x1d,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;
_L2102F:
    r3=dm(i6,m7);
    r0=dm(i6,m1);
    r1=dm(i6,m1);
    r2=dm(i6,m1);
    r4=dm(0x30413);
    f8=f4-f0;
    r5=dm(0x30414);
    f9=f5-f1;
    r6=dm(0x30415);
    f10=f6-f2, dm(0x3,i3)=r8;
    dm(0x4,i3)=r9;
    dm(0x5,i3)=r10;
    r0=dm(0x30406);
    f8=f0-f8;
    r1=dm(0x30407);
    f9=f1-f9;
    r2=dm(0x30408);
    f10=f2-f10, dm(0x9,i3)=r8;
    dm(0xa,i3)=r9;
    dm(0xb,i3)=r10;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L21047;
    jump _L20F8D;
_L21047:
    i6=0x30303;
    i7=0x30403;
    lcntr=0x9, do (pc,0x2) until lce;
    r0=dm(i6,m1);
    dm(i7,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x3,i3);
    r1=dm(0x4,i3);
    r2=dm(0x5,i3);
    r4=dm(0x9,i3);
    f8=f0*f4, r5=dm(0xa,i3);
    f9=f1*f5, r6=dm(0xb,i3);
    f10=f2*f6;
    f8=f8+f9;
    f8=f8+f10;
    f13=-f8;
    if le jump _L21075;
    f8=f4*f4;
    f9=f5*f5;
    f10=f6*f6;
    f8=f8+f9;
    f8=f8+f10, dm(0xc,i3)=r13;
    f9=f8-f13, dm(0xd,i3)=r8;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    if le jump _L2107C;
    r2=r8;
    r1=r13;
    call _L205D0;
    r4=dm(0x9,i3);
    f4=f4*f0, r8=dm(0x3,i3);
    f4=f4+f8, r5=dm(0xa,i3);
    f5=f5*f0, dm(0x9,i3)=r4;
    r9=dm(0x4,i3);
    f5=f5+f9, r6=dm(0xb,i3);
    f6=f6*f0, r10=dm(0x5,i3);
    f6=f6+f10, dm(0xa,i3)=r5;
    f4=f4*f4;
    f5=f5*f5;
    f6=f6*f6, dm(0xb,i3)=r6;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    rts (db);
    f4=f4+f5;
    f8=f4+f6;
_L21075:
    r0=dm(0x3,i3);
    f0=f0*f0, r1=dm(0x4,i3);
    f1=f1*f1, r2=dm(0x5,i3);
    f2=f2*f2;
    rts (db);
    f4=f0+f1;
    f8=f4+f2;
_L2107C:
    r0=dm(0x6,i3);
    f0=f0*f0, r1=dm(0x7,i3);
    f1=f1*f1, r2=dm(0x8,i3);
    f2=f2*f2;
    rts (db);
    f4=f0+f1;
    f8=f4+f2;
_L21083:
    i5=0x1403d80;
    i7=0x1407e20;
    r2=dm(0x17,i3);
    r3=dm(0x18,i3);
    r4=0x1e;
    r5=0x1f;
    r14=0;
    r10=0;
_L2108B:
    m6=r10;
    i6=0x307a0;
    r0=dm(m6,i6);
    r15=r0-r14;
    if eq jump _L210AD;
    r11=0;
    r1=dm(m6,i7);
_L21092:
    btst r1 by r11;
    if sz jump _L210A9;
    m6=r11;
    i6=0x306a0;
    r12=dm(m6,i6);
    r15=r12-r14;
    if eq jump _L210A9;
    btst r3 by r10;
    if sz jump _L2109F;
    r15=r11-r4;
    if eq jump _L210A9;
    r15=r11-r5;
    if eq jump _L210A9;
_L2109F:
    btst r2 by r11;
    if sz jump _L210A5;
    r15=r10-r4;
    if eq jump _L210A9;
    r15=r10-r5;
    if eq jump _L210A9;
_L210A5:
    m6=r12;
    r9=dm(m6,i5);
    r9=bset r9 by r0;
    dm(m6,i5)=r9;
_L210A9:
    r11=r11+1;
    r13=0x20;
    r15=r11-r13;
    if ne jump _L21092;
_L210AD:
    r10=r10+1;
    r13=0x20;
    r15=r10-r13;
    if ne jump _L2108B;
    rts;

// ----------------------------------------------------------------------------
// Fn_coli_trans_xz             [official source label]   dispatch 0x3E  opcode 0x1F003E3E
//   in=5  out=0    PM 0x210B2   collision-space XZ transform
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r8=dm(m0,i0);
    f4=f8*f8;
    if flag0_in jump (pc, 0);
    r9=dm(m0,i0);
    f5=f9*f9;
    f5=f4+f5;
    call _L2029B;
    f0=f8*f4;
    f1=f9*f4;
    if flag0_in jump (pc, 0);
    r13=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r14=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r15=dm(m0,i0);
    call _L210CD (db);
    i7=0x1403e80;
    i6=0x1403f40;
    call _L210CD (db);
    i7=0x1403ee0;
    i6=0x1403fa0;
    call _L210CD (db);
    i7=0x1407e80;
    i6=0x1407f40;
    i7=0x1407ee0;
    i6=0x1407fa0;
_L210CD:
    lcntr=0x20, do (pc,0xb) until lce;
    r8=dm(i7,m1);
    f4=f8-f13, r10=dm(m1,i7);
    f8=f0*f4, f5=f10-f15;
    r9=dm(i7,m2);
    f12=f1*f5, f11=f9-f14;
    f2=f0*f5, f8=f8+f12;
    dm(i6,m1)=r8;
    f3=f1*f4;
    dm(i6,m1)=r11;
    f2=f2-f3;
    dm(i6,m1)=r2;
    rts;

// ----------------------------------------------------------------------------
// Fn_fcurve_lin                [official source label]   dispatch 0x31  opcode 0x18803131
//   in=4  out=1    PM 0x210DA   linear key interpolation: a + (b-a)*t/span
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r14=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    f8=f4-f14;
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    f1=f8*f2;
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    call _L205D0;
    f0=f0+f14;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_fcurve_spl                [official source label]   dispatch 0x32  opcode 0x19003232
//   in=6  out=1    PM 0x210E9   Hermite cubic spline key interpolation
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r4=0x3d08882f;
    f8=f0*f4, r1=dm(m1,i3);
    call _L205D0 (db);
    dm(0x9,i3)=r8;
    r2=r8;
    dm(0x3,i3)=r0;
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    r4=0x3d08882f;
    f8=f1*f4;
    f8=f8*f0;
    dm(0x4,i3)=r8;
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r3=dm(m0,i0);
    f8=f2*f0;
    f9=f3*f0;
    dm(0x5,i3)=r8;
    f10=f8-f9;
    dm(0x3,i3)=r10;
    f10=f10+f10;
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    dm(0x6,i3)=r10;
    dm(0x7,i3)=r2;
    if flag0_in jump (pc, 0);
    r3=dm(m0,i0);
    f11=f2+f3;
    dm(0x8,i3)=r11;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    f11=f11+f10;
    r8=dm(0x4,i3);
    f11=f11*f8;
    f11=f11-f10;
    r9=dm(0x3,i3);
    f11=f11-f9;
    r9=dm(0x8,i3);
    f11=f11-f9;
    r9=dm(0x7,i3);
    f11=f11-f9;
    r10=dm(0x4,i3);
    f11=f11*f10;
    f11=f11+f9;
    f11=f11*f10;
    r8=dm(0x5,i3);
    f11=f11+f8;
    r8=dm(0x9,i3);
    f11=f11*f8;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r11;
    rts;

// ----------------------------------------------------------------------------
// Fn_base_zy                   [official source label]   dispatch 0x4F  opcode 0x27804F4F
//   in=0  out=0    PM 0x21120   STUB in this revision (bare rts at PM 0x21120)
// Fn_base_yz                   [official source label]   dispatch 0x50  opcode 0x28005050
//   in=0  out=0    PM 0x21120   STUB in this revision (bare rts at PM 0x21120)
// Fn_base_zyx_ang              [official source label]   dispatch 0x52  opcode 0x29005252
//   in=0  out=0    PM 0x21120   STUB in this revision (bare rts at PM 0x21120)
// Fn_base_zyx                  [official source label]   dispatch 0x53  opcode 0x29805353
//   in=0  out=0    PM 0x21120   STUB in this revision (bare rts at PM 0x21120)
// Fn_calc_unit_2               [official source label]   dispatch 0x60  opcode 0x30006060
//   in=0  out=0    PM 0x21120   STUB in this revision (bare rts at PM 0x21120)
// Fn_calc_unit_1               [official source label]   dispatch 0x61  opcode 0x30806161
//   in=0  out=0    PM 0x21120   STUB in this revision (bare rts at PM 0x21120)
// ----------------------------------------------------------------------------
    rts;

// ----------------------------------------------------------------------------
// Fn_get_sm_ang_f              [official source label]   dispatch 0x54  opcode 0x2A005454
//   in=9  out=3    PM 0x21121   "smooth angle" forward: identity + 9 ang ops, then extract 3 i16 Euler angles
// ----------------------------------------------------------------------------
    call _L2039B;
    i7=dm(0x3033f);
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201AA;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201BF;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201D4;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201D4;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201BF;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201AA;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201BF;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201AA;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201D4;
    jump _L2117C;

// ----------------------------------------------------------------------------
// Fn_get_glo_ang_zyx           [official source label]   dispatch 0x76  opcode 0x3B007676
//   in=?  out=?    PM 0x2113F   global Euler angles in ZYX order
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    call _L202CA (db);
    r0=dm(0x8,i7);
    r1=dm(0x5,i7);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    r1=dm(0x2,i7);
    call _L20332;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    call _L202CA (db);
    r0=dm(0,i7);
    r1=dm(0x1,i7);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_glo_ang               [official source label]   dispatch 0x51  opcode 0x28805151
//   in=0  out=3    PM 0x2114F   extract the global Euler angles from the current matrix
// ----------------------------------------------------------------------------
    i7=dm(0x3033f);
    call _L202CA (db);
    r0=dm(0x8,i7);
    r1=dm(0x6,i7);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    r1=dm(0x7,i7);
    call _L20332;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    call _L202CA (db);
    r0=dm(0x4,i7);
    r1=dm(0x1,i7);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// ----------------------------------------------------------------------------
// Fn_get_sm_ang_r              [official source label]   dispatch 0x55  opcode 0x2A805555
//   in=0  out=0    PM 0x2115F   "smooth angle" reverse  (MAME-observed: 0 in, 0 out)
// ----------------------------------------------------------------------------
    call _L2039B;
    i7=dm(0x3033f);
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201D4;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201AA;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201BF;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201AA;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201BF;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201D4;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201D4;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201BF;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201AA;
_L2117C:
    i7=dm(0x3033f);
    call _L202D1 (db);
    r0=dm(0x8,i7);
    r1=dm(0x6,i7);
    dm(0x3,i3)=r0;
    r1=dm(0x7,i7);
    call _L2033F;
    dm(0x4,i3)=r0;
    call _L202D1 (db);
    r0=dm(0x4,i7);
    r1=dm(0x1,i7);
    dm(0x5,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r10=0x40490fd7;
    r15=0;
    r3=dm(0x3,i3);
    f12=f3+f10;
    f7=f3-f10;
    comp(f15,f3);
    if gt r7=r12;
    f4=abs f3;
    f0=abs f7;
    r3=dm(0x4,i3);
    f13=f3+f10;
    r0=0xbf800000;
    f13=f13*f0;
    f8=f10-f3;
    comp(f15,f3);
    if gt r8=r13;
    f5=abs f3;
    f1=abs f8;
    r3=dm(0x5,i3);
    f14=f3+f10;
    f9=f3-f10;
    comp(f15,f3);
    if gt r9=r14;
    f6=abs f3;
    f2=abs f9;
    f0=f0+f1;
    f0=f0+f2;
    f4=f4+f5;
    f4=f4+f6;
    comp(f0,f4);
    if le jump _L211AC;
    r7=dm(0x3,i3);
    r8=dm(0x4,i3);
    r9=dm(0x5,i3);
_L211AC:
    r5=0x4622f983;
    f7=f7*f5;
    f8=f8*f5;
    f9=f9*f5;
    r7=fix f7;
    r8=fix f8;
    r9=fix f9;
    r7=lshift r7 by 0x10;
    r7=lshift r7 by -16;
    r8=lshift r8 by 0x10;
    r8=lshift r8 by -16;
    r9=lshift r9 by 0x10;
    r9=lshift r9 by -16;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r7;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r8;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r9;
    rts;

// ==============================================================================
// _L211C0  ROT_MAT_FROM_AXIS_ANGLE  (PM 0x211C0)  helper
// Build 3x3 rotation matrix from axis (f0,f1,f2) and precomputed sin/cos
// in DM[0x3040C]=cos(a) and DM[0x3040D]=sin(a) via Rodrigues formula.
// Result written directly to current bone slot at i7.
// ==============================================================================
_L211C0:
    r8=dm(0x3040c);
    f10=f8*f2;
    f10=-f10;
    f11=f8*f3, dm(0x1,i7)=r10;
    dm(0,i7)=r11;
    r7=dm(0x3040d);
    f12=f0*f2;
    f10=f3*f7;
    r15=r10;
    f10=f10*f1;
    f10=f10+f12;
    f15=f15*f0;
    f11=f2*f1, dm(0x3,i7)=r10;
    f12=f15-f11;
    f12=-f12;
    f11=f11*f7, dm(0x6,i7)=r12;
    f10=f3*f0;
    f6=f3*f1;
    f12=f11-f10;
    dm(0x2,i7)=r7;
    f12=-f12;
    dm(0x4,i7)=r12;
    f9=f2*f7;
    f9=f9*f0;
    f12=f9+f6;
    f11=f8*f1, dm(0x7,i7)=r12;
    f13=f8*f0;
    dm(0x8,i7)=r13;
    f11=-f11;
    dm(0x5,i7)=r11;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ----------------------------------------------------------------------------
// Fn_calc_unit_hara            [official source label]   dispatch 0x62  opcode 0x31006262
//   in=9  out=0    PM 0x211E1   "hara" (torso) unit-matrix solve
// ----------------------------------------------------------------------------
    call _L20375;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    i7=dm(0x3033f);
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x9,i7)=r0;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0xa,i7)=r0;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0xb,i7)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L202C1;
    r2=r1;
    r3=r0;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L202C1;
    dm(0x3040d)=r1;
    dm(0x3040c)=r0;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L202C1;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L211C0;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201BF;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201AA;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    jump _L201D4;

// ----------------------------------------------------------------------------
// Fn_get_loc_pos               [official source label]   dispatch 0x63  opcode 0x31806363
//   in=7  out=3    PM 0x21209   world -> local position about a reference point + Y angle: [(E-A)cosD+(G-C)sinD, F-B, (G-C)cosD-(E-A)sinD]
// ----------------------------------------------------------------------------
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x3,i3)=r0;
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    dm(0x5,i3)=r2;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r3=dm(m0,i0);
    dm(0x6,i3)=r3;
    if flag0_in jump (pc, 0);
    r8=dm(m0,i0);
    f8=f8-f1;
    if flag0_in jump (pc, 0);
    r9=dm(m0,i0);
    call _L202C1 (db);
    dm(0x8,i3)=r9;
    dm(0x10,i3)=r8;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r8=dm(0x6,i3);
    f8=f8*f0, r11=dm(0x8,i3);
    f11=f11*f1, r4=dm(0x5,i3);
    f9=f4*f1;
    f11=f11+f8;
    f11=f11-f9, r5=dm(0x3,i3);
    f12=f5*f0;
    f11=f11-f12, r13=dm(0x8,i3);
    f14=f13*f0;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r11;
    r2=dm(0x10,i3);
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r2;
    f10=f5*f1, r3=dm(0x6,i3);
    f11=f10+f14, r4=dm(0x5,i3);
    f12=f3*f1;
    f8=f0*f4;
    f11=f11-f12;
    f11=f11-f8;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r11;
    rts;

// ----------------------------------------------------------------------------
// Fn_mul_mot_yrot              [official source label]   dispatch 0x69  opcode 0x34806969
//   in=?  out=?    PM 0x21237   multiply by the motion Y rotation (axis-angle matrix build, _L211C0)
// ----------------------------------------------------------------------------
    r4=0x1400000;
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    r1=r1+r4;
    i7=r1;
    i6=0x30410;
    lcntr=0x9, do (pc,0x2) until lce;
    r2=dm(i7,m1);
    dm(i6,m1)=r2;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L202C1;
    i6=0x30410;
    i7=dm(0x3033f);
    r4=dm(0,i6);
    f8=f0*f4, r5=dm(0x2,i6);
    f13=f1*f5, r4=dm(0x3,i6);
    f8=f8-f13, r5=dm(0x5,i6);
    f9=f0*f4, dm(0,i7)=r8;
    f14=f1*f5, r4=dm(0x6,i6);
    f9=f9-f14, r5=dm(0x8,i6);
    f10=f0*f4, dm(0x3,i7)=r9;
    f15=f1*f5, r4=dm(0,i6);
    f10=f10-f15, r5=dm(0x2,i6);
    f8=f1*f4, dm(0x6,i7)=r10;
    f13=f0*f5, r4=dm(0x3,i6);
    f8=f8+f13, r5=dm(0x5,i6);
    f9=f1*f4, dm(0x2,i7)=r8;
    f14=f0*f5, r4=dm(0x6,i6);
    f9=f9+f14, r5=dm(0x8,i6);
    f10=f1*f4, dm(0x5,i7)=r9;
    f15=f0*f5, r4=dm(0x1,i6);
    f10=f10+f15, dm(0x3,i3)=r4;
    dm(0x8,i7)=r10;
    r5=dm(0x4,i6);
    dm(0x4,i3)=r5;
    r6=dm(0x7,i6);
    dm(0x5,i3)=r6;
    dm(0x1,i7)=r4;
    dm(0x4,i7)=r5;
    dm(0x7,i7)=r6;
    rts (db);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;

// ==============================================================================
// _L21265  CLIP_ANGLE_PAIR  (PM 0x21265)  helper
// Clip (f0,f1) to [-1.0,+1.0] using SHARC clip instruction.
// Limits come from DM[0xC,i3] and DM[0xD,i3].
// ==============================================================================
_L21265:
    r0=dm(0xc,i3);
    r2=0x3f800000;
    f0=clip f0 by f2;
    rts (db);
    r1=dm(0xd,i3);
    f1=clip f1 by f2;

// ----------------------------------------------------------------------------
// Fn_calc_unit_2_fast          [official source label]   dispatch 0x6B  opcode 0x35806B6B
//   in=17 out=1    PM 0x2126B   2-bone IK solve (STF: calc_rob_angle_cont)
// ----------------------------------------------------------------------------
    call _L203BB;
    i7=dm(0x3033f);
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201D4;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201BF;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201AA;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201BF;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201AA;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    call _L201D4;
    if flag0_in jump (pc, 0);
    r0=dm(m0,i0);
    dm(0x3,i3)=r0;
    if flag0_in jump (pc, 0);
    r1=dm(m0,i0);
    dm(0x4,i3)=r1;
    if flag0_in jump (pc, 0);
    r2=dm(m0,i0);
    dm(0x5,i3)=r2;
    if flag0_in jump (pc, 0);
    r4=dm(m0,i0);
    dm(0x11,i3)=r4;
    if flag0_in jump (pc, 0);
    r5=dm(m0,i0);
    dm(0x13,i3)=r5;
    if flag0_in jump (pc, 0);
    r6=dm(m0,i0);
    dm(0x1d,i3)=r6;
    if flag0_in jump (pc, 0);
    r7=dm(m0,i0);
    dm(0x1e,i3)=r7;
    if flag0_in jump (pc, 0);
    r15=dm(m0,i0);
    dm(0x1f,i3)=r15;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r7=dm(0x9,i7);
    f7=f0-f7, r10=dm(0xa,i7);
    f10=f1-f10, r8=dm(0xb,i7);
    f8=f2-f8, dm(0x3,i3)=r7;
    dm(0x4,i3)=r10;
    dm(0x5,i3)=r8;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r4=dm(0,i7);
    f11=f7*f4, r5=dm(0x1,i7);
    f12=f10*f5, r6=dm(0x2,i7);
    f13=f8*f6, r9=dm(0x3,i7);
    f11=f11+f12, r3=dm(0x4,i7);
    f11=f11+f13, r0=dm(0x5,i7);
    f12=f9*f7, dm(0x14,i3)=r11;
    f11=f3*f10;
    f13=f0*f8;
    f11=f11+f12, r0=dm(0x6,i7);
    f11=f11+f13, r1=dm(0x7,i7);
    f11=-f11, r2=dm(0x8,i7);
    dm(0x15,i3)=r11;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    f11=f0*f7;
    f12=f1*f10;
    f13=f2*f8;
    f11=f11+f12, r0=dm(0x14,i3);
    f2=f11+f13, r1=dm(0x15,i3);
    f4=f0*f0, dm(0x16,i3)=r2;
    f5=f1*f1;
    f6=f2*f2;
    f4=f4+f5;
    call _L202AE (db);
    dm(0x10,i3)=r4;
    f0=f4+f6;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L2029B (db);
    dm(0x12,i3)=r0;
    r5=dm(0x10,i3);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    dm(0x18,i3)=r4;
    r0=dm(0x10,i3);
    f0=f0*f4;
    dm(0x17,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L205D0 (db);
    r1=dm(m1,i3);
    r2=dm(0x12,i3);
    dm(0x19,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    i7=dm(0x3033f);
    r0=dm(0x18,i3);
    r4=dm(0x14,i3);
    r6=dm(0x15,i3);
    f4=f0*f4;
    f5=f0*f6, dm(0xc,i3)=r4;
    dm(0xd,i3)=r5;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L21265;
    call _L201D7;
    r0=dm(0x19,i3);
    r4=dm(0x17,i3);
    r6=dm(0x16,i3);
    f4=f0*f4;
    f5=f0*f6, dm(0xc,i3)=r4;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L21265 (db);
    dm(0xd,i3)=r5;
    i7=dm(0x3033f);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L201C2;
    r0=dm(0x11,i3);
    r4=dm(0x13,i3);
    f10=f0+f4, r1=dm(0x12,i3);
    comp(r10,r1);
    if le jump _L21342;
    r0=dm(0x11,i3);
    f4=f0*f0, r1=dm(0x12,i3);
    f5=f1*f1, r2=dm(0x13,i3);
    f6=f2*f2, dm(0x1a,i3)=r4;
    dm(0x1b,i3)=r5;
    dm(0x1c,i3)=r6;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x1b,i3);
    r4=dm(0x1a,i3);
    f8=f0+f4, r1=dm(0x1c,i3);
    f8=f8-f1, r2=dm(0x12,i3);
    r5=dm(0x11,i3);
    f11=f2*f5, r3=dm(m2,i3);
    call _L205D0 (db);
    f2=f11*f3;
    r1=r8;
    dm(0xc,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L202AE (db);
    f4=f0*f0, r8=dm(m1,i3);
    f0=f8-f4;
    r15=dm(0x1f,i3);
    r14=0;
    comp(r15,r14);
    if eq f0=-f0;
    dm(0xd,i3)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L21265;
    call _L201D7;
    r2=0x1400000;
    r3=dm(0x1d,i3);
    r2=r2+r3;
    i6=r2;
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i7,m1);
    dm(i6,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=dm(0x1a,i3);
    r4=dm(0x1c,i3);
    f8=f0+f4, r1=dm(0x1b,i3);
    f8=f8-f1, r2=dm(0x11,i3);
    r5=dm(0x13,i3);
    f11=f2*f5, r3=dm(m2,i3);
    call _L205D0 (db);
    f2=f11*f3;
    r1=r8;
    f1=-f0;
    f4=f0*f0, r8=dm(m1,i3);
    call _L202AE (db);
    dm(0xc,i3)=r1;
    f0=f8-f4;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r15=dm(0x1f,i3);
    r14=0;
    comp(r15,r14);
    if ne f0=-f0;
    call _L21265 (db);
    dm(0xd,i3)=r0;
    i7=dm(0x3033f);
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    call _L201D7;
    r2=0x1400000;
    r3=dm(0x1e,i3);
    r2=r2+r3;
    i6=r2;
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i7,m1);
    dm(i6,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=0;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;

// -- ik_solver_35806B6B: chain too short, copy bone to both target outputs --
_L21342:
    r2=0x1400000;
    r3=dm(0x1d,i3);
    r2=r2+r3;
    i6=r2;
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i7,m1);
    dm(i6,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r2=0x1400000;
    r3=dm(0x1e,i3);
    r2=r2+r3;
    i6=r2;
    i7=dm(0x3033f);
    lcntr=0xc, do (pc,0x2) until lce;
    r0=dm(i7,m1);
    dm(i6,m1)=r0;
    dm(0x20,i3)=r15;
    dm(0x20,i3)=r15;
    r0=0;
    if flag1_in jump (pc, 0);
    dm(m0,i1)=r0;
    rts;
