unit MB3DFormulaThunks;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ASMMODE Intel}{$ENDIF}

interface

uses TypeDefinitions;

function BindHeadlessFormulaThunk(Index: Integer; Code: Pointer): ThybridIteration2;

implementation

var
  RawFormulaCode: array[0..5] of Pointer;

{$IFDEF CPU386}
{ Compiled .m3f code uses MB3D's historical private ABI. In the current
  packed record ESI is TIteration3D + 88 (x is at ESI-120), while EDI points
  at the formula variables. }
procedure FormulaThunk0(var x, y, z, w: Double; PIteration3D: Pointer); assembler; nostackframe;
asm
  push esi
  push edi
  mov esi, [esp + 12]
  add esi, 88
  mov edi, [esi - 40]
  call dword ptr [RawFormulaCode + 0]
  pop edi
  pop esi
  ret 8
end;

procedure FormulaThunk1(var x, y, z, w: Double; PIteration3D: Pointer); assembler; nostackframe;
asm
  push esi
  push edi
  mov esi, [esp + 12]
  add esi, 88
  mov edi, [esi - 40]
  call dword ptr [RawFormulaCode + 4]
  pop edi
  pop esi
  ret 8
end;

procedure FormulaThunk2(var x, y, z, w: Double; PIteration3D: Pointer); assembler; nostackframe;
asm
  push esi
  push edi
  mov esi, [esp + 12]
  add esi, 88
  mov edi, [esi - 40]
  call dword ptr [RawFormulaCode + 8]
  pop edi
  pop esi
  ret 8
end;

procedure FormulaThunk3(var x, y, z, w: Double; PIteration3D: Pointer); assembler; nostackframe;
asm
  push esi
  push edi
  mov esi, [esp + 12]
  add esi, 88
  mov edi, [esi - 40]
  call dword ptr [RawFormulaCode + 12]
  pop edi
  pop esi
  ret 8
end;

procedure FormulaThunk4(var x, y, z, w: Double; PIteration3D: Pointer); assembler; nostackframe;
asm
  push esi
  push edi
  mov esi, [esp + 12]
  add esi, 88
  mov edi, [esi - 40]
  call dword ptr [RawFormulaCode + 16]
  pop edi
  pop esi
  ret 8
end;

procedure FormulaThunk5(var x, y, z, w: Double; PIteration3D: Pointer); assembler; nostackframe;
asm
  push esi
  push edi
  mov esi, [esp + 12]
  add esi, 88
  mov edi, [esi - 40]
  call dword ptr [RawFormulaCode + 20]
  pop edi
  pop esi
  ret 8
end;
{$ENDIF}

function BindHeadlessFormulaThunk(Index: Integer; Code: Pointer): ThybridIteration2;
begin
  Result := nil;
  if not (Index in [0..5]) then Exit;
  RawFormulaCode[Index] := Code;
  {$IFDEF CPU386}
  case Index of
    0: Result := FormulaThunk0;
    1: Result := FormulaThunk1;
    2: Result := FormulaThunk2;
    3: Result := FormulaThunk3;
    4: Result := FormulaThunk4;
    5: Result := FormulaThunk5;
  end;
  {$ENDIF}
end;

end.
