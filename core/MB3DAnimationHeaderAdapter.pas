unit MB3DAnimationHeaderAdapter;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses
  MB3DAnimationModel, TypeDefinitions;

function DecodeMB3DAnimationV5Header(const Source: TMB3DAnimationV5Header;
  out Header: TMandHeader10; out ErrorText: string): Boolean;
procedure BindMB3DHeaderRuntimePointers(var Header: TMandHeader10;
  var HeaderAddon: THeaderCustomAddon; const FormulaPointers: array of Pointer);

implementation

const
  DiskPointerOffset = 382;
  DiskPointerBytes = 28;
  DiskTailOffset = DiskPointerOffset + DiskPointerBytes;
  DiskTailBytes = MB3DAnimationV5HeaderSize - DiskTailOffset;

function DecodeMB3DAnimationV5Header(const Source: TMB3DAnimationV5Header;
  out Header: TMandHeader10; out ErrorText: string): Boolean;
const
  NativePointerBytes = SizeOf(Pointer) * 7;
  NativeTailOffset = DiskPointerOffset + NativePointerBytes;
begin
  Result := False;
  ErrorText := '';
  FillChar(Header, SizeOf(Header), 0);
  if SizeOf(Pointer) = 4 then
  begin
    if SizeOf(Header) <> MB3DAnimationV5HeaderSize then
    begin
      ErrorText := 'Unsupported 32-bit TMandHeader10 layout';
      Exit;
    end;
    Move(Source[0], Header, MB3DAnimationV5HeaderSize);
  end
  else if SizeOf(Pointer) = 8 then
  begin
    if SizeOf(Header) <> MB3DAnimationV5HeaderSize + DiskPointerBytes then
    begin
      ErrorText := 'Unsupported 64-bit TMandHeader10 layout';
      Exit;
    end;
    Move(Source[0], Header, DiskPointerOffset);
    Move(Source[DiskTailOffset], PByte(@Header)[NativeTailOffset], DiskTailBytes);
  end
  else
  begin
    ErrorText := 'Unsupported pointer size';
    Exit;
  end;
  Result := True;
end;

procedure BindMB3DHeaderRuntimePointers(var Header: TMandHeader10;
  var HeaderAddon: THeaderCustomAddon; const FormulaPointers: array of Pointer);
var
  FormulaIndex: Integer;
begin
  Header.PCFAddon := @HeaderAddon;
  for FormulaIndex := 0 to 5 do
    if FormulaIndex <= High(FormulaPointers) then
      Header.PHCustomF[FormulaIndex] := FormulaPointers[FormulaIndex]
    else
      Header.PHCustomF[FormulaIndex] := nil;
end;

end.
