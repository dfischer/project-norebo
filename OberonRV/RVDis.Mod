(*
  Interface assumes 32-bit INTEGERs.
*)

MODULE RVDis;
IMPORT Texts;

TYPE
  WOP = PROCEDURE(VAR W: Texts.Writer; op, fn3: INTEGER);

VAR
  i: INTEGER;
  decoderTable: ARRAY 32 OF WOP;
  bxxTable, lxTable, sxTable, sysTable,
    mulTable,
    alu1Table, alu2Table, alu3Table, alu4Table,
    alu5Table, alu6Table, alu7Table, alu8Table:
      ARRAY 8, 9 OF CHAR;

PROCEDURE writeHex(VAR W: Texts.Writer; n: INTEGER);
BEGIN
  Texts.WriteHex(W, n); Texts.Write(W, 48X);
END writeHex;

PROCEDURE unknown(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN
  Texts.WriteString(W, "WORD   ");
  writeHex(W, op)
END unknown;

PROCEDURE WriteOpcode*(VAR W: Texts.Writer; op: INTEGER);
(*
  Write the textual representation of a valid RISC-V opcode to the writer.
  If the instruction isn't supported by this disassembler, the translation
  is treated as a raw DWORD directive.
*)
VAR
  opcode, fn3: INTEGER;
BEGIN
  IF op MOD 4 # 3 THEN
    (* 16-bit compressed instructions not yet supported. *)
    unknown(W, op, fn3);
  ELSE
    (*
      Bits 6:2 of the instruction determines the instruction form,
      and contributes to the instruction's opcode.

      If supported, bits 14:12 provide another 3 bits for the opcode.
    *)
    opcode := (op DIV 4) MOD 32;
    fn3 := (op DIV 4096) MOD 8;
    decoderTable[opcode](W, op, fn3);
  END
END WriteOpcode;

PROCEDURE writeReg(VAR W: Texts.Writer; r: INTEGER);
BEGIN
  Texts.WriteInt(W, r, 0); Texts.WriteString(W, ", ");
END writeReg;

PROCEDURE fmtU(VAR W: Texts.Writer; op, fn3: INTEGER; insn: ARRAY OF CHAR);
VAR
  rd: INTEGER;
BEGIN
  rd := op DIV 128 MOD 32;

  Texts.WriteString(W, insn);
  writeReg(W, rd);
  writeHex(W, op DIV 1000H * 1000H);
END fmtU;

PROCEDURE fmtUJ(VAR W: Texts.Writer; op, fn3: INTEGER; insn: ARRAY OF CHAR);
VAR
  offset, rd: INTEGER;
BEGIN
  rd := op DIV 128 MOD 32;
  offset := LSL(ASR(op, 31), 20) + LSL(ASR(op, 21) MOD 1024, 1) +
      LSL(ASR(op, 20) MOD 2, 11) + LSL(ASR(op, 12) MOD 256, 12);
  Texts.WriteString(W, insn);
  writeReg(W, rd);
  writeHex(W, offset)
END fmtUJ;

PROCEDURE fmtI(VAR W: Texts.Writer; op, fn3: INTEGER; insn: ARRAY OF CHAR);
VAR
  rd, rs1, imm: INTEGER;
BEGIN
  rd := op DIV 128 MOD 32;
  rs1 := op DIV 8000H MOD 32;
  imm := op DIV 100000H;
  Texts.WriteString(W, insn);
  writeReg(W, rd); writeReg(W, rs1);
  Texts.WriteInt(W, imm, 0);
END fmtI;

PROCEDURE fmtR(VAR W: Texts.Writer; op, fn3: INTEGER; insn: ARRAY OF CHAR);
VAR
  rd, rs1, rs2: INTEGER;
BEGIN
  rd := op DIV 128 MOD 32;
  rs1 := op DIV 8000H MOD 32;
  rs2 := ASR(op, 20) MOD 32;
  Texts.WriteString(W, insn);
  writeReg(W, rd); writeReg(W, rs1);
  Texts.WriteInt(W, rs2, 0);
END fmtR;

PROCEDURE fmtSB(VAR W: Texts.Writer; op, fn3: INTEGER; insn: ARRAY OF CHAR);
VAR
  offset, rs1, rs2: INTEGER;
BEGIN
  offset := (ASR(op, 31)) * 1000H +
            (ASR(op, 25) MOD 64) * 20H +
            (ASR(op, 8) MOD 16) * 2H +
            (ASR(op, 7) MOD 2) * 800H;
  rs1 := ASR(op, 15) MOD 32;
  rs2 := ASR(op, 20) MOD 32;
  Texts.WriteString(W, insn);
  writeReg(W, rs1); writeReg(W, rs2); Texts.WriteInt(W, offset, 0);
END fmtSB;

PROCEDURE fmtS(VAR W: Texts.Writer; op, fn3: INTEGER; insn: ARRAY OF CHAR);
VAR
  offset, rs1, rs2: INTEGER;
BEGIN
  offset := ASR(op, 25) * 32 + ASR(op, 7) MOD 32;
  rs1 := ASR(op, 15) MOD 32;
  rs2 := ASR(op, 20) MOD 32;
  Texts.WriteString(W, insn);
  (*
    We swap the register order for the store instructions, so that their
    register layouts would correspond in an assembly language listing.
    For example, given:

      LH x1, 200(x2)

    we expect X1 to contain the half-word at 200(X2).  To put X1 back there,
    it's very convenient to write:

      SH x1, 200(x2)

    Otherwise, you'd have to read this, which I think you'll agree is more
    difficult to read:

      SH x2, x1, 200

    Note that the assembler must be aware of this register swap as well.
    See RVAssem.Mod.
  *)
  writeReg(W, rs2); writeReg(W, rs1); Texts.WriteInt(W, offset, 0);
END fmtS;

PROCEDURE lui(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN fmtU(W, op, fn3, "LUI     ");
END lui;

PROCEDURE auipc(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN fmtU(W, op, fn3, "AUIPC   ");
END auipc;

PROCEDURE jal(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN fmtUJ(W, op, fn3, "JAL     ");
END jal;

PROCEDURE jalr(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN fmtI(W, op, fn3, "JALR    ");
END jalr;

PROCEDURE bxx(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN fmtSB(W, op, fn3, bxxTable[fn3]);
END bxx;

PROCEDURE lx(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN fmtI(W, op, fn3, lxTable[fn3]);
END lx;

PROCEDURE sx(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN fmtS(W, op, fn3, sxTable[fn3]);
END sx;

PROCEDURE alui(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN
  IF (fn3 IN {1, 5}) & ODD(op DIV 40000000H) THEN
    fmtI(W, op MOD 40000000H, fn3, alu1Table[fn3])
  ELSE
    fmtI(W, op, fn3, alu2Table[fn3])
  END
END alui;

PROCEDURE aluiw(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN
  IF (fn3 IN {1,5}) & ODD(op DIV 40000000H) THEN
    fmtI(W, op MOD 40000000H, fn3, alu5Table[fn3])
  ELSE
    fmtI(W, op, fn3, alu6Table[fn3])
  END
END aluiw;

PROCEDURE system(VAR W: Texts.Writer; op, fn3: INTEGER);
VAR
  rd, rs1, csr: INTEGER;
BEGIN
  rd := op DIV 128 MOD 32;
  rs1 := op DIV 8000H MOD 32;
  csr := op DIV 100000H MOD 1000H;

  IF fn3 = 0 THEN
    IF csr = 0 THEN Texts.WriteString(W, "ECALL   ");
    ELSIF csr = 1 THEN Texts.WriteString(W, "EBREAK  ");
    ELSE Texts.WriteString(W, "E?????? ");
    END
  ELSIF fn3 IN {1, 2, 3, 5, 6, 7} THEN
    Texts.WriteString(W, sysTable[fn3]);
    writeReg(W, rd); writeReg(W, rs1);
    writeHex(W, csr);
  ELSE
    unknown(W, op, fn3);
  END
END system;

PROCEDURE addsub(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN
  IF (fn3 IN {0, 1, 5}) & ODD(op DIV 40000000H) THEN
    fmtR(W, op MOD 40000000H, fn3, alu3Table[fn3])
  ELSE
    fmtR(W, op, fn3, alu4Table[fn3])
  END
END addsub;

PROCEDURE muldiv(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN
  fmtR(W, op, fn3, mulTable[fn3])
END muldiv;

PROCEDURE alur(VAR W: Texts.Writer; op, fn3: INTEGER);
VAR fn7: INTEGER;
BEGIN
  fn7 := ASR(op, 25) MOD 128;
  IF (fn7 = 0) OR (fn7 = 20H) THEN addsub(W, op, fn3)
  ELSIF fn7 = 1 THEN muldiv(W, op, fn3)
  ELSE unknown(W, op, fn3)
  END
END alur;

PROCEDURE alurw(VAR W: Texts.Writer; op, fn3: INTEGER);
BEGIN
  IF (fn3 IN {1, 5}) & ODD(op DIV 40000000H) THEN
    fmtR(W, op MOD 40000000H, fn3, alu7Table[fn3])
  ELSE
    fmtR(W, op, fn3, alu8Table[fn3])
  END
END alurw;

BEGIN
  FOR i := 0 TO 31 DO decoderTable[i] := unknown END;
  decoderTable[03H DIV 4] := lx;
  decoderTable[13H DIV 4] := alui;
  decoderTable[17H DIV 4] := auipc;
  decoderTable[1BH DIV 4] := aluiw;
  decoderTable[23H DIV 4] := sx;
  decoderTable[33H DIV 4] := alur;
  decoderTable[37H DIV 4] := lui;
  decoderTable[3BH DIV 4] := alurw;
  decoderTable[63H DIV 4] := bxx;
  decoderTable[67H DIV 4] := jalr;
  decoderTable[6FH DIV 4] := jal;
  decoderTable[73H DIV 4] := system;

  bxxTable[0] := "BEQ     ";
  bxxTable[1] := "BNE     ";
  bxxTable[2] := "B?2     ";
  bxxTable[3] := "B?3     ";
  bxxTable[4] := "BLT     ";
  bxxTable[5] := "BGE     ";
  bxxTable[6] := "BLTU    ";
  bxxTable[7] := "BGEU    ";

  lxTable[0] := "LB      ";
  lxTable[1] := "LH      ";
  lxTable[2] := "LW      ";
  lxTable[3] := "LD      ";
  lxTable[4] := "LBU     ";
  lxTable[5] := "LHU     ";
  lxTable[6] := "LWU     ";
  lxTable[7] := "LDU     ";

  sxTable[0] := "SB      ";
  sxTable[1] := "SH      ";
  sxTable[2] := "SW      ";
  sxTable[3] := "SD      ";
  sxTable[4] := "SBU??   ";
  sxTable[5] := "SHU??   ";
  sxTable[6] := "SWU??   ";
  sxTable[7] := "SDU??   ";

  alu1Table[0] := "ADDI    ";
  alu1Table[1] := "???I    ";
  alu1Table[2] := "SLTI    ";
  alu1Table[3] := "SLTIU   ";
  alu1Table[4] := "XORI    ";
  alu1Table[5] := "SRAI    ";
  alu1Table[6] := "ORI     ";
  alu1Table[7] := "ANDI    ";

  alu2Table[0] := "ADDI    ";
  alu2Table[1] := "SLLI    ";
  alu2Table[2] := "SLTI    ";
  alu2Table[3] := "SLTIU   ";
  alu2Table[4] := "XORI    ";
  alu2Table[5] := "SRLI    ";
  alu2Table[6] := "ORI     ";
  alu2Table[7] := "ANDI    ";

  alu3Table[0] := "SUB     ";
  alu3Table[1] := "???     ";
  alu3Table[2] := "SLT     ";
  alu3Table[3] := "SLTU    ";
  alu3Table[4] := "XOR     ";
  alu3Table[5] := "SRA     ";
  alu3Table[6] := "OR      ";
  alu3Table[7] := "AND     ";

  alu4Table[0] := "ADD     ";
  alu4Table[1] := "SLL     ";
  alu4Table[2] := "SLT     ";
  alu4Table[3] := "SLTU    ";
  alu4Table[4] := "XOR     ";
  alu4Table[5] := "SRL     ";
  alu4Table[6] := "OR      ";
  alu4Table[7] := "AND     ";

  alu5Table[0] := "ADDIW   ";
  alu5Table[1] := "????W   ";
  alu5Table[2] := "????W   ";
  alu5Table[3] := "????W   ";
  alu5Table[4] := "????W   ";
  alu5Table[5] := "SRAIW   ";
  alu5Table[6] := "????W   ";
  alu5Table[7] := "????W   ";

  alu6Table[0] := "ADDIW   ";
  alu6Table[1] := "SLLIW   ";
  alu6Table[2] := "????W   ";
  alu6Table[3] := "????W   ";
  alu6Table[4] := "????W   ";
  alu6Table[5] := "SRLIW   ";
  alu6Table[6] := "????W   ";
  alu6Table[7] := "????W   ";

  alu7Table[0] := "SUBW    ";
  alu7Table[1] := "????    ";
  alu7Table[2] := "????    ";
  alu7Table[3] := "????    ";
  alu7Table[4] := "????    ";
  alu7Table[5] := "SRAW    ";
  alu7Table[6] := "????    ";
  alu7Table[7] := "????    ";

  alu8Table[0] := "ADDW    ";
  alu8Table[1] := "SLLW    ";
  alu8Table[2] := "????    ";
  alu8Table[3] := "????    ";
  alu8Table[4] := "????    ";
  alu8Table[5] := "SRLW    ";
  alu8Table[6] := "????    ";
  alu8Table[7] := "????    ";

  mulTable[0] := "MUL     ";
  mulTable[1] := "MULH    ";
  mulTable[2] := "MULHSU  ";
  mulTable[3] := "MULHU   ";
  mulTable[4] := "DIV     ";
  mulTable[5] := "DIVU    ";
  mulTable[6] := "REM     ";
  mulTable[7] := "REMU    ";

  sysTable[0] := "CSR???  ";
  sysTable[1] := "CSRRW   ";
  sysTable[2] := "CSRRS   ";
  sysTable[3] := "CSRRC   ";
  sysTable[4] := "CSR???I ";
  sysTable[5] := "CSRRWI  ";
  sysTable[6] := "CSRRSI  ";
  sysTable[7] := "CSRRCI  ";
END RVDis.

