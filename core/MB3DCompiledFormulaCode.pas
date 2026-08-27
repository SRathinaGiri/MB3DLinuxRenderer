unit MB3DCompiledFormulaCode;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses
  Classes;

const
  MB3DCompiledFormulaCapacity = 4096;

type
  TMB3DCompiledFormulaCode = class
  private
    FMemory: Pointer;
    FCodeSize: Integer;
  public
    destructor Destroy; override;
    function DetachMemory: Pointer;
    property Memory: Pointer read FMemory;
    property CodeSize: Integer read FCodeSize;
  end;

function LoadMB3DCompiledFormulaCode(const FileName: string;
  out FormulaCode: TMB3DCompiledFormulaCode; out ErrorText: string): Boolean;

implementation

uses
  SysUtils, MB3DExecutableMemory;

function IsHexCharacter(const Value: Char): Boolean;
begin
  Result := ((Value >= '0') and (Value <= '9')) or
            ((Value >= 'a') and (Value <= 'f')) or
            ((Value >= 'A') and (Value <= 'F'));
end;

function HexValue(const Value: Char): Byte;
begin
  if (Value >= '0') and (Value <= '9') then
    Result := Ord(Value) - Ord('0')
  else if (Value >= 'a') and (Value <= 'f') then
    Result := Ord(Value) - Ord('a') + 10
  else
    Result := Ord(Value) - Ord('A') + 10;
end;

destructor TMB3DCompiledFormulaCode.Destroy;
begin
  FreeMB3DExecutableMemory(FMemory, MB3DCompiledFormulaCapacity);
  inherited Destroy;
end;

function TMB3DCompiledFormulaCode.DetachMemory: Pointer;
begin
  Result := FMemory;
  FMemory := nil;
  FCodeSize := 0;
end;

function LoadMB3DCompiledFormulaCode(const FileName: string;
  out FormulaCode: TMB3DCompiledFormulaCode; out ErrorText: string): Boolean;
var
  Lines: TStringList;
  InCodeSection: Boolean;
  Line, CleanLine: string;
  LineIndex, CharacterIndex: Integer;
  WritePointer: PByte;
begin
  Result := False;
  FormulaCode := nil;
  ErrorText := '';
  if not FileExists(FileName) then
  begin
    ErrorText := 'Formula file not found: ' + FileName;
    Exit;
  end;

  Lines := TStringList.Create;
  try
    try
      Lines.LoadFromFile(FileName);
    except
      on E: Exception do
      begin
        ErrorText := 'Unable to read formula file: ' + E.Message;
        Exit;
      end;
    end;

    FormulaCode := TMB3DCompiledFormulaCode.Create;
    FormulaCode.FMemory := AllocateMB3DExecutableMemory(MB3DCompiledFormulaCapacity);
    if FormulaCode.FMemory = nil then
    begin
      FormulaCode.Free;
      FormulaCode := nil;
      ErrorText := 'Unable to allocate executable formula memory';
      Exit;
    end;
    FillChar(FormulaCode.FMemory^, MB3DCompiledFormulaCapacity, 0);
    WritePointer := FormulaCode.FMemory;
    InCodeSection := False;

    for LineIndex := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[LineIndex]);
      if SameText(Line, '[CODE]') then
      begin
        InCodeSection := True;
        Continue;
      end;
      if not InCodeSection then
        Continue;
      if (Length(Line) > 0) and (Line[1] = '[') then
        Break;

      CleanLine := '';
      for CharacterIndex := 1 to Length(Line) do
      begin
        if Line[CharacterIndex] <= ' ' then
          Continue;
        if not IsHexCharacter(Line[CharacterIndex]) then
        begin
          ErrorText := Format('Invalid code character in %s at line %d',
            [ExtractFileName(FileName), LineIndex + 1]);
          FormulaCode.Free;
          FormulaCode := nil;
          Exit;
        end;
        CleanLine := CleanLine + Line[CharacterIndex];
      end;
      if Odd(Length(CleanLine)) then
      begin
        ErrorText := Format('Odd number of hexadecimal digits in %s at line %d',
          [ExtractFileName(FileName), LineIndex + 1]);
        FormulaCode.Free;
        FormulaCode := nil;
        Exit;
      end;
      for CharacterIndex := 1 to Length(CleanLine) div 2 do
      begin
        if FormulaCode.FCodeSize >= MB3DCompiledFormulaCapacity - 1 then
        begin
          ErrorText := 'Compiled formula exceeds 4096-byte MB3D limit: ' +
            ExtractFileName(FileName);
          FormulaCode.Free;
          FormulaCode := nil;
          Exit;
        end;
        WritePointer^ := (HexValue(CleanLine[CharacterIndex * 2 - 1]) shl 4) or
          HexValue(CleanLine[CharacterIndex * 2]);
        Inc(WritePointer);
        Inc(FormulaCode.FCodeSize);
      end;
    end;

    if not InCodeSection then
    begin
      ErrorText := 'Formula contains no [CODE] section (source/JIT formulas are unsupported)';
      FormulaCode.Free;
      FormulaCode := nil;
      Exit;
    end;
    if FormulaCode.FCodeSize <= 10 then
    begin
      ErrorText := 'Formula [CODE] section is empty or too short';
      FormulaCode.Free;
      FormulaCode := nil;
      Exit;
    end;
    Result := True;
  finally
    Lines.Free;
  end;
end;

end.
