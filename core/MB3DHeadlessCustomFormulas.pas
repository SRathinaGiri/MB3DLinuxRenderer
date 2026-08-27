unit MB3DHeadlessCustomFormulas;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses
  TypeDefinitions;

var
  CFdescription: String;
  CFdescriptionIntern: array[0..9] of String = (
    'Integer Power', 'Real Power', 'Quaternion', 'Tricorn', 'Amazing Box',
    'Bulbox', 'Folding Int Pow', 'test', 'testIFS', 'Aexion C');

procedure SetMB3DFormulaDirectory(const DirectoryName: string);
function LoadCustomFormulaFromHeader(var CustomFname: array of Byte;
  var Formula: TCustomFormula; var DefaultOptions: array of Double): Boolean;
function AssignCustomFormula(Destination, Source: PTCustomFormula): LongBool;
procedure MakeCustomFsFromHeader(Header: TMandHeader10);
procedure SetCFoptionsFromOldF(FormulaIndex: Integer; Formula: PTCustomFormula);
procedure CopyTypeAndOptionFromCFtoHAddon(Formula: PTCustomFormula;
  HeaderAddon: PTHeaderCustomAddon; FormulaIndex: Integer);
procedure CheckHybridOptions(HeaderAddon: PTHeaderCustomAddon);

implementation

uses
  Classes, Math, SysUtils, Math3D, formulas, MB3DHeadlessUtils,
  MB3DCompiledFormulaCode, MB3DExecutableMemory;

var
  FormulaDirectory: string = 'assets/formulas';

procedure SetMB3DFormulaDirectory(const DirectoryName: string);
begin
  FormulaDirectory := ExcludeTrailingPathDelimiter(DirectoryName);
end;

procedure CheckHybridOptions(HeaderAddon: PTHeaderCustomAddon);
var
  Index, End1, Repeat1, Start2, End2, Repeat2: Integer;
begin
  if (HeaderAddon.bOptions1 and 3) = 1 then
  begin
    End1 := 0; Repeat1 := 0; Start2 := 1; End2 := 5; Repeat2 := 1;
  end
  else
  begin
    Index := 5;
    while (Index > 0) and (HeaderAddon.Formulas[Index].iItCount = 0) do Dec(Index);
    Start2 := Max(1, Min(Index, HeaderAddon.bHybOpt2 and 7));
    if (HeaderAddon.bOptions1 and 3) = 0 then End1 := Index else End1 := Start2 - 1;
    End2 := Max(Start2, Index);
    Repeat2 := Max(Start2, Min(End2, (HeaderAddon.bHybOpt2 shr 8) and 7));
    Index := End1;
    while (Index > 0) and (HeaderAddon.Formulas[Index].iItCount <= 0) do Dec(Index);
    Repeat1 := Min(Index, HeaderAddon.bHybOpt1 shr 4);
    if (HeaderAddon.bOptions1 and 3) = 2 then
    begin
      Index := 5;
      while (Index > Start2) and (HeaderAddon.Formulas[Index].iItCount <= 0) do Dec(Index);
      Repeat2 := Min(Index, Repeat2);
    end;
  end;
  HeaderAddon.bHybOpt1 := End1 or (Repeat1 shl 4);
  HeaderAddon.bHybOpt2 := Start2 or (End2 shl 4) or (Repeat2 shl 8);
end;

procedure CopyTypeAndOptionFromCFtoHAddon(Formula: PTCustomFormula;
  HeaderAddon: PTHeaderCustomAddon; FormulaIndex: Integer);
var
  Index: Integer;
begin
  for Index := 0 to 15 do
    HeaderAddon.Formulas[FormulaIndex].byOptionType[Index] := Formula.byOptionTypes[Index];
  HeaderAddon.Formulas[FormulaIndex].iOptionCount := Formula.iCFOptionCount;
end;

procedure SetCFoptionsFromOldF(FormulaIndex: Integer; Formula: PTCustomFormula);
var
  Index: Integer;
const
  Names: array[0..9, 0..1] of string =
    (('Integer power (2..8)','Z multiplier'), ('Float power','Z multiplier'),
     ('YW multiplier','W add'), ('Z multiplier','CZ multiplier'), ('Scale','Min R'),
     ('Box Scale','Box Min R'), ('Integer power (2..8)','Z multiplier'), ('',''),
     ('',''), ('Float power','Z multiplier'));
begin
  if not (FormulaIndex in [0..9]) then Exit;
  for Index := 0 to 15 do Formula.byOptionTypes[Index] := 0;
  Formula.iCFOptionCount := 2;
  Formula.sOptionStrings[0] := Names[FormulaIndex, 0];
  Formula.sOptionStrings[1] := Names[FormulaIndex, 1];
  if FormulaIndex in [0, 6] then Formula.byOptionTypes[0] := 10;
  if FormulaIndex in [4, 5] then Formula.byOptionTypes[1] := 7;
  if FormulaIndex = 4 then
  begin
    Formula.iCFOptionCount := 3;
    Formula.sOptionStrings[2] := 'Fold';
    Formula.byOptionTypes[2] := 11;
  end
  else if FormulaIndex = 5 then
  begin
    Formula.iCFOptionCount := 6;
    Formula.sOptionStrings[2] := 'Box fold';
    Formula.sOptionStrings[3] := 'Bulb scaling';
    Formula.sOptionStrings[4] := 'Box/Bulb R threshold';
    Formula.sOptionStrings[5] := 'Box/Bulb R threshold 2';
    Formula.byOptionTypes[2] := 11;
    Formula.byOptionTypes[4] := 9;
    Formula.byOptionTypes[5] := 9;
  end
  else if FormulaIndex = 6 then
  begin
    Formula.iCFOptionCount := 3;
    Formula.byOptionTypes[2] := 8;
    Formula.sOptionStrings[2] := 'R fold';
  end;
end;

function TextAfterEquals(const Line: string): string;
var
  EqualsPosition: Integer;
begin
  EqualsPosition := Pos('=', Line);
  if EqualsPosition = 0 then Result := ''
  else Result := Trim(Copy(Line, EqualsPosition + 1, MaxInt));
end;

function InvariantFloat(const Value: string): Double;
var
  Settings: TFormatSettings;
begin
  Settings := DefaultFormatSettings;
  Settings.DecimalSeparator := '.';
  Result := StrToFloat(StringReplace(Value, ',', '.', [rfReplaceAll]), Settings);
end;

function OptionTypeFromName(const Name: string): Integer;
var
  Key: string;
begin
  Key := UpperCase(Name);
  if Key = '.DOUBLE' then Result := 0 else
  if Key = '.SINGLE' then Result := 1 else
  if Key = '.INTEGER' then Result := 2 else
  if Key = '.DOUBLEANGLE' then Result := 3 else
  if Key = '.SINGLEANGLE' then Result := 4 else
  if Key = '.3DOUBLEANGLES' then Result := 5 else
  if Key = '.3SINGLEANGLES' then Result := 6 else
  if Key = '.BOXSCALE' then Result := 7 else
  if Key = '.FOLDING' then Result := 8 else
  if Key = '.DSQUARE' then Result := 9 else
  if Key = '.NOVARIABLE' then Result := 10 else
  if Key = '.FOLDING16' then Result := 11 else
  if Key = '.6SINGLEANGLES' then Result := 12 else
  if Key = '.DRECIPRO' then Result := 13 else
  if Key = '.2DOUBLES' then Result := 14 else
  if Key = '.DSQRRECI' then Result := 15 else
  if Key = '.2SINGLES' then Result := 16 else
  if Key = '.4SINGLES' then Result := 17 else
  if Key = '.3SCALESANGLES' then Result := 18 else
  if Key = '.SCALESROT' then Result := 19 else
  if Key = '.2INTEGER' then Result := 20 else
  if Key = '.SRECI2' then Result := 21 else
  if Key = '.DRECI2' then Result := 22 else Result := -1;
end;

procedure InitializeFormulaRecord(var Formula: TCustomFormula);
begin
  Formula.SIMDlevel := 0;
  Formula.iCFOptionCount := 0;
  Formula.dDEscale := 1;
  Formula.dADEscale := 1;
  Formula.dSIpow := 0;
  Formula.dRstop := 16;
  Formula.iConstCount := 0;
  Formula.iDEoption := 0;
  Formula.iVersion := 0;
  Formula.pConstPointer16 := nil;
  Formula.bCPmemReserved := False;
  Pointer(Formula.pCodePointer) := nil;
  SetLength(Formula.VarBuffer, 1024);
  Formula.pConstPointer16 := Pointer((PtrUInt(@Formula.VarBuffer[0]) + 271) and not PtrUInt($F));
end;

function LoadCustomFormulaFromHeader(var CustomFname: array of Byte;
  var Formula: TCustomFormula; var DefaultOptions: array of Double): Boolean;
var
  FileName, Line, OptionName, LabelText: string;
  Lines: TStringList;
  Code: TMB3DCompiledFormulaCode;
  Index, SpacePosition, EqualsPosition, OptionType, SubIndex: Integer;
  DefaultValue: Double;
const
  Rotation6Labels: array[0..5] of string = (' YZ',' XZ',' XY',' XW',' YW',' ZW');
begin
  Result := False;
  InitializeFormulaRecord(Formula);
  FileName := IncludeTrailingPathDelimiter(FormulaDirectory) +
    string(CustomFtoStr(CustomFname)) + '.m3f';
  Lines := TStringList.Create;
  Code := nil;
  try
    Lines.LoadFromFile(FileName);
    for Index := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[Index]);
      if SameText(Copy(Line, 1, 8), '.Version') then Formula.iVersion := StrToInt(TextAfterEquals(Line)) else
      if SameText(Copy(Line, 1, 9), '.DEoption') then Formula.iDEoption := StrToInt(TextAfterEquals(Line)) else
      if SameText(Copy(Line, 1, 8), '.DEscale') then Formula.dDEscale := InvariantFloat(TextAfterEquals(Line)) else
      if SameText(Copy(Line, 1, 9), '.ADEscale') then Formula.dADEscale := InvariantFloat(TextAfterEquals(Line)) else
      if SameText(Copy(Line, 1, 6), '.RStop') then Formula.dRstop := InvariantFloat(TextAfterEquals(Line)) else
      if SameText(Copy(Line, 1, 5), '.SIPo') then Formula.dSIpow := InvariantFloat(TextAfterEquals(Line)) else
      if (Length(Line) > 1) and (Line[1] = '.') and (Pos('=', Line) > 0) then
      begin
        SpacePosition := Pos(' ', Line);
        EqualsPosition := Pos('=', Line);
        if (SpacePosition = 0) or (SpacePosition > EqualsPosition) then
          OptionName := Copy(Line, 1, EqualsPosition - 1)
        else
          OptionName := Copy(Line, 1, SpacePosition - 1);
        OptionType := OptionTypeFromName(Trim(OptionName));
        if (OptionType >= 0) and (Formula.iCFOptionCount < 16) then
        begin
          LabelText := Trim(Copy(Line, Length(OptionName) + 1,
            EqualsPosition - Length(OptionName) - 1));
          DefaultValue := InvariantFloat(TextAfterEquals(Line));
          if OptionType in [5, 6] then
          begin
            for SubIndex := 0 to 2 do
              if Formula.iCFOptionCount < 16 then
              begin
                Formula.byOptionTypes[Formula.iCFOptionCount] := OptionType;
                Formula.sOptionStrings[Formula.iCFOptionCount] := LabelText +
                  ' ' + Chr(Ord('X') + SubIndex);
                DefaultOptions[Formula.iCFOptionCount] := DefaultValue;
                Inc(Formula.iCFOptionCount);
              end;
          end
          else if OptionType = 12 then
          begin
            for SubIndex := 0 to 5 do
              if Formula.iCFOptionCount < 16 then
              begin
                Formula.byOptionTypes[Formula.iCFOptionCount] := OptionType;
                Formula.sOptionStrings[Formula.iCFOptionCount] := LabelText +
                  Rotation6Labels[SubIndex];
                DefaultOptions[Formula.iCFOptionCount] := DefaultValue;
                Inc(Formula.iCFOptionCount);
              end;
          end
          else
          begin
            Formula.byOptionTypes[Formula.iCFOptionCount] := OptionType;
            Formula.sOptionStrings[Formula.iCFOptionCount] := LabelText;
            DefaultOptions[Formula.iCFOptionCount] := DefaultValue;
            Inc(Formula.iCFOptionCount);
          end;
        end;
      end;
    end;
    if not LoadMB3DCompiledFormulaCode(FileName, Code, Line) then Exit;
    Pointer(Formula.pCodePointer) := Code.DetachMemory;
    Formula.bCPmemReserved := True;
    Result := (Formula.iVersion >= 2) and (Formula.pCodePointer <> nil);
  except
    Result := False;
  end;
  Code.Free;
  Lines.Free;
end;

procedure FillSimpleVariables(Formula: PTCustomFormula; const Values: array of Double);
var
  Index, SubIndex, RepeatCount: Integer;
  SinglePointer, MatrixSingleValue: PSingle;
  MatrixDoubleValue: PDouble;
  Matrix: TMatrix3;
  Matrix4: TSMatrix4;
  Angles: array[0..5] of Double;
begin
  SinglePointer := Formula.pConstPointer16;
  Dec(SinglePointer, 2);
  PDouble(SinglePointer)^ := 0.5;
  Index := 0;
  while Index < Min(Formula.iCFOptionCount, Length(Values)) do
  begin
    case Formula.byOptionTypes[Index] of
      0, 10: begin Dec(SinglePointer, 2); PDouble(SinglePointer)^ := Values[Index]; end;
      1: begin Dec(SinglePointer); SinglePointer^ := Values[Index]; end;
      2: begin Dec(SinglePointer); PInteger(SinglePointer)^ := Round(Values[Index]); end;
      3: begin Dec(SinglePointer, 2); PDouble(SinglePointer)^ := Sin(Values[Index] * Pid180);
               Dec(SinglePointer, 2); PDouble(SinglePointer)^ := Cos(Values[Index] * Pid180); end;
      4: begin Dec(SinglePointer); SinglePointer^ := Sin(Values[Index] * Pid180);
               Dec(SinglePointer); SinglePointer^ := Cos(Values[Index] * Pid180); end;
      5: begin
           BuildRotMatrix(Values[Index] * Pid180, Values[Index + 1] * Pid180,
             Values[Index + 2] * Pid180, @Matrix);
           MatrixDoubleValue := @Matrix[0, 0];
           for SubIndex := 0 to 8 do
           begin Dec(SinglePointer, 2); PDouble(SinglePointer)^ := MatrixDoubleValue^;
             Inc(MatrixDoubleValue); end;
           Inc(Index, 2);
         end;
      6: begin
           BuildRotMatrix(Values[Index] * Pid180, Values[Index + 1] * Pid180,
             Values[Index + 2] * Pid180, @Matrix);
           MatrixDoubleValue := @Matrix[0, 0];
           for SubIndex := 0 to 8 do
           begin Dec(SinglePointer); SinglePointer^ := MatrixDoubleValue^;
             Inc(MatrixDoubleValue); end;
           Inc(Index, 2);
         end;
      7: begin Dec(SinglePointer, 2); PDouble(SinglePointer)^ := Values[Max(0, Index - 1)] /
                 Sqr(Max(1e-40, Values[Index])); Dec(SinglePointer, 2);
                 PDouble(SinglePointer)^ := Sqr(Max(1e-40, Values[Index])); end;
      8: begin
           Dec(SinglePointer, 2); PDouble(SinglePointer)^ := Values[Index];
           Dec(SinglePointer, 2); PDouble(SinglePointer)^ := 2 * Values[Index];
           Dec(SinglePointer, 2); PDouble(SinglePointer)^ := -Values[Index];
           Dec(SinglePointer, 2); PDouble(SinglePointer)^ := -2 * Values[Index];
           Dec(SinglePointer);
           if Index > 1 then
             TPhybridIteration(SinglePointer)^ :=
               fHIntFunctions[Max(2, Min(8, Round(Values[Index - 2])))];
         end;
      9: begin Dec(SinglePointer, 2); PDouble(SinglePointer)^ := Sqr(Values[Index]); end;
      11: begin
            Dec(SinglePointer, 2); PDouble(SinglePointer)^ := Values[Index];
            Dec(SinglePointer, 2); PDouble(SinglePointer)^ := Values[Index];
            Dec(SinglePointer, 2); PDouble(SinglePointer)^ := -Values[Index];
            Dec(SinglePointer, 2); PDouble(SinglePointer)^ := -Values[Index];
          end;
      12: begin
            for SubIndex := 0 to 5 do Angles[SubIndex] := Values[Index + SubIndex] * Pid180;
            BuildRotMatrix4d(Angles, Matrix4);
            MatrixSingleValue := @Matrix4[0];
            for SubIndex := 0 to 15 do
            begin Dec(SinglePointer); SinglePointer^ := MatrixSingleValue^;
              Inc(MatrixSingleValue); end;
            Inc(Index, 5);
          end;
      13: begin Dec(SinglePointer, 2); PDouble(SinglePointer)^ := 1 / Max(1e-40, Abs(Values[Index])); end;
      14: begin Dec(SinglePointer, 2); PDouble(SinglePointer)^ := Values[Index];
                Dec(SinglePointer, 2); PDouble(SinglePointer)^ := Values[Index]; end;
      15: begin Dec(SinglePointer, 2); PDouble(SinglePointer)^ := 1 / Max(1e-40, Sqr(Values[Index])); end;
      16, 17: begin
                if Formula.byOptionTypes[Index] = 17 then RepeatCount := 4
                else RepeatCount := 2;
                while RepeatCount > 0 do
                begin Dec(SinglePointer); SinglePointer^ := Values[Index];
                  Dec(RepeatCount); end;
              end;
      18: begin
            BuildRotMatrix(Values[Index + 1] * Pid180, Values[Index + 2] * Pid180,
              Values[Index + 3] * Pid180, @Matrix);
            ScaleMatrix(Values[Index], @Matrix);
            MatrixDoubleValue := @Matrix[0, 0];
            for SubIndex := 0 to 8 do
            begin Dec(SinglePointer); SinglePointer^ := MatrixDoubleValue^;
              Inc(MatrixDoubleValue); end;
            Inc(Index, 3);
          end;
      19: begin
            Dec(SinglePointer); SinglePointer^ := Sin(Values[Index + 1] * Pid180) * Values[Index];
            Dec(SinglePointer); SinglePointer^ := Cos(Values[Index + 1] * Pid180) * Values[Index];
            Inc(Index);
          end;
      20: begin Dec(SinglePointer); PInteger(SinglePointer)^ := Round(Values[Index]);
                Dec(SinglePointer); PInteger(SinglePointer)^ := Round(Values[Index]); end;
      21: begin Dec(SinglePointer); SinglePointer^ := Values[Index]; Dec(SinglePointer);
                SinglePointer^ := 1 / Max(1e-30, Abs(Values[Index])); end;
      22: begin Dec(SinglePointer, 2); PDouble(SinglePointer)^ := Values[Index];
                Dec(SinglePointer, 2); PDouble(SinglePointer)^ := 1 / Max(1e-40, Abs(Values[Index])); end;
    end;
    Inc(Index);
  end;
end;

procedure ParseInternalFormula(FormulaIndex: Integer; Formula: PTCustomFormula;
  const Values: array of Double);
const
  DEScale: array[0..9] of Double = (1,1,1,1,0.2,0.2,0.5,1,1,1);
begin
  SetCFoptionsFromOldF(FormulaIndex, Formula);
  Formula.dDEscale := DEScale[FormulaIndex];
  Formula.dADEscale := 1;
  Formula.dSIpow := 2;
  if FormulaIndex in [0, 1, 9] then Formula.dSIpow := Max(2, Values[0]);
  Formula.dRstop := 16;
  if FormulaIndex in [4,5,6] then Formula.dRstop := 1024;
  Formula.iDEoption := 0;
  Formula.iVersion := 3;
  SetLength(Formula.VarBuffer, 1024);
  Formula.pConstPointer16 := Pointer((PtrUInt(@Formula.VarBuffer[0]) + 271) and not PtrUInt($F));
  Move(PAligned16^, Formula.pConstPointer16^, 216);
  Formula.bCPmemReserved := False;
  case FormulaIndex of
    0: ThybridIteration(Formula.pCodePointer) := fHIntFunctions[Round(Formula.dSIpow)];
    1: ThybridIteration(Formula.pCodePointer) := HybridFloatPow;
    2: begin ThybridIteration(Formula.pCodePointer) := fHybridQuat; Formula.iDEoption := 4; end;
    3: ThybridIteration(Formula.pCodePointer) := HybridItTricorn;
    4: begin ThybridIteration(Formula.pCodePointer) := fHybridCubeDE; Formula.iDEoption := 11; end;
    5: ThybridIteration(Formula.pCodePointer) := HybridSuperCube2;
    6: ThybridIteration(Formula.pCodePointer) := HybridFolding;
    7: ThybridIteration(Formula.pCodePointer) := TestHybrid;
    8: TIFSIteration(Formula.pCodePointer) := HybridCustomIFStest;
    9: ThybridIteration(Formula.pCodePointer) := AexionC;
  end;
end;

procedure MakeCustomFsFromHeader(Header: TMandHeader10);
var
  Index, LastIndex: Integer;
  Formula: PTCustomFormula;
  Defaults: array[0..15] of Double;
begin
  if (PTHeaderCustomAddon(Header.PCFAddon).bOptions1 and 3) = 1 then LastIndex := 1 else LastIndex := 5;
  for Index := 0 to LastIndex do
    with PTHeaderCustomAddon(Header.PCFAddon).Formulas[Index] do
      if (LastIndex = 1) or (iItCount > 0) then
      begin
        Formula := PTCustomFormula(Header.PHCustomF[Index]);
        if iFnr < 20 then ParseInternalFormula(iFnr, Formula, dOptionValue)
        else if not LoadCustomFormulaFromHeader(CustomFname, Formula^, Defaults) then
        begin
          iItCount := 0;
          Break;
        end;
        FillSimpleVariables(Formula, dOptionValue);
      end;
end;

function AssignCustomFormula(Destination, Source: PTCustomFormula): LongBool;
var
  Index: Integer;
begin
  Result := (Source <> nil) and (Source.pCodePointer <> nil);
  if not Result then Exit;
  if Destination.bCPmemReserved and (Destination.pCodePointer <> nil) then
    FreeMB3DExecutableMemory(Pointer(Destination.pCodePointer), 4096);
  for Index := 0 to 15 do
  begin
    Destination.sOptionStrings[Index] := Source.sOptionStrings[Index];
    Destination.byOptionTypes[Index] := Source.byOptionTypes[Index];
  end;
  Destination.SIMDlevel := Source.SIMDlevel;
  Destination.iCFOptionCount := Source.iCFOptionCount;
  Destination.dDEscale := Source.dDEscale;
  Destination.dADEscale := Source.dADEscale;
  Destination.dSIpow := Source.dSIpow;
  Destination.dRstop := Source.dRstop;
  Destination.iConstCount := Source.iConstCount;
  Destination.iDEoption := Source.iDEoption;
  Destination.iVersion := Source.iVersion;
  Destination.LastModTime := Source.LastModTime;
  SetLength(Destination.VarBuffer, 1024);
  Destination.pConstPointer16 := Pointer((PtrUInt(@Destination.VarBuffer[0]) + 271) and not PtrUInt($F));
  Move(Pointer(PtrUInt(Source.pConstPointer16) - 256)^,
    Pointer(PtrUInt(Destination.pConstPointer16) - 256)^, 1008);
  Destination.bCPmemReserved := Source.bCPmemReserved;
  if Source.bCPmemReserved then
  begin
    Pointer(Destination.pCodePointer) := AllocateMB3DExecutableMemory(4096);
    if Destination.pCodePointer = nil then Exit(False);
    Move(Source.pCodePointer^, Destination.pCodePointer^, 4096);
  end
  else
    Destination.pCodePointer := Source.pCodePointer;
end;

end.
