unit MB3DPortablePNG;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses SysUtils;

type
  TByteBuffer = array of Byte;

function SaveGray8PNG(const FileName: string; Width, Height: Integer;
  const Pixels: TByteBuffer; out ErrorText: string): Boolean;
function SaveRGB8PNG(const FileName: string; Width, Height: Integer;
  const Pixels: TByteBuffer; out ErrorText: string): Boolean;

implementation

uses Classes;

procedure AppendByte(var Data: TByteBuffer; Value: Byte);
var N: Integer;
begin
  N := Length(Data);
  SetLength(Data, N + 1);
  Data[N] := Value;
end;

procedure AppendCardinalBE(var Data: TByteBuffer; Value: Cardinal);
begin
  AppendByte(Data, Value shr 24);
  AppendByte(Data, Value shr 16);
  AppendByte(Data, Value shr 8);
  AppendByte(Data, Value);
end;

function CRC32Update(CRC: Cardinal; Value: Byte): Cardinal;
var BitIndex: Integer;
begin
  Result := CRC xor Value;
  for BitIndex := 0 to 7 do
    if (Result and 1) <> 0 then Result := (Result shr 1) xor $EDB88320
    else Result := Result shr 1;
end;

procedure WriteCardinalBE(Stream: TStream; Value: Cardinal);
var Bytes: array[0..3] of Byte;
begin
  Bytes[0] := Value shr 24; Bytes[1] := Value shr 16;
  Bytes[2] := Value shr 8; Bytes[3] := Value;
  Stream.WriteBuffer(Bytes, SizeOf(Bytes));
end;

procedure WriteChunk(Stream: TStream; const Kind: AnsiString;
  const Data: TByteBuffer);
var CRC: Cardinal;
    Index: Integer;
begin
  WriteCardinalBE(Stream, Length(Data));
  Stream.WriteBuffer(Kind[1], 4);
  if Length(Data) > 0 then Stream.WriteBuffer(Data[0], Length(Data));
  CRC := $FFFFFFFF;
  for Index := 1 to 4 do CRC := CRC32Update(CRC, Ord(Kind[Index]));
  for Index := 0 to High(Data) do CRC := CRC32Update(CRC, Data[Index]);
  WriteCardinalBE(Stream, CRC xor $FFFFFFFF);
end;

function DeflateStored(const Raw: TByteBuffer): TByteBuffer;
var Position, OutputPosition, BlockSize, BlockCount, Index: Integer;
    A, B: Cardinal;
begin
  Result := nil;
  if Length(Raw) = 0 then BlockCount := 1
  else BlockCount := (Length(Raw) + 65534) div 65535;
  SetLength(Result, 2 + BlockCount * 5 + Length(Raw) + 4);
  OutputPosition := 0;
  Result[OutputPosition] := $78; Inc(OutputPosition);
  Result[OutputPosition] := $01; Inc(OutputPosition);
  Position := 0;
  repeat
  begin
    BlockSize := Length(Raw) - Position;
    if BlockSize > 65535 then BlockSize := 65535;
    if Position + BlockSize = Length(Raw) then Result[OutputPosition] := 1
    else Result[OutputPosition] := 0;
    Inc(OutputPosition);
    Result[OutputPosition] := BlockSize and $FF; Inc(OutputPosition);
    Result[OutputPosition] := BlockSize shr 8; Inc(OutputPosition);
    Result[OutputPosition] := (not BlockSize) and $FF; Inc(OutputPosition);
    Result[OutputPosition] := ((not BlockSize) shr 8) and $FF; Inc(OutputPosition);
    if BlockSize > 0 then
    begin
      Move(Raw[Position], Result[OutputPosition], BlockSize);
      Inc(OutputPosition, BlockSize);
    end;
    Inc(Position, BlockSize);
  end
  until Position >= Length(Raw);
  A := 1; B := 0;
  for Index := 0 to High(Raw) do
  begin
    A := (A + Raw[Index]) mod 65521;
    B := (B + A) mod 65521;
  end;
  Result[OutputPosition] := B shr 8; Inc(OutputPosition);
  Result[OutputPosition] := B; Inc(OutputPosition);
  Result[OutputPosition] := A shr 8; Inc(OutputPosition);
  Result[OutputPosition] := A;
end;

function SaveGray8PNG(const FileName: string; Width, Height: Integer;
  const Pixels: TByteBuffer; out ErrorText: string): Boolean;
const Signature: array[0..7] of Byte = ($89,$50,$4E,$47,$0D,$0A,$1A,$0A);
var Stream: TFileStream;
    IHDR, Raw, Compressed, Empty: TByteBuffer;
    X, Y, RawPosition: Integer;
begin
  Result := False;
  ErrorText := '';
  if (Width <= 0) or (Height <= 0) or (Length(Pixels) <> Width * Height) then
  begin
    ErrorText := 'Invalid grayscale image dimensions';
    Exit;
  end;
  try
    if ExtractFileDir(FileName) <> '' then ForceDirectories(ExtractFileDir(FileName));
    SetLength(IHDR, 13);
    IHDR[0] := Width shr 24; IHDR[1] := Width shr 16;
    IHDR[2] := Width shr 8; IHDR[3] := Width;
    IHDR[4] := Height shr 24; IHDR[5] := Height shr 16;
    IHDR[6] := Height shr 8; IHDR[7] := Height;
    IHDR[8] := 8; IHDR[9] := 0;
    SetLength(Raw, (Width + 1) * Height);
    RawPosition := 0;
    for Y := 0 to Height - 1 do
    begin
      Raw[RawPosition] := 0;
      Inc(RawPosition);
      for X := 0 to Width - 1 do
      begin
        Raw[RawPosition] := Pixels[Y * Width + X];
        Inc(RawPosition);
      end;
    end;
    Compressed := DeflateStored(Raw);
    Stream := TFileStream.Create(FileName, fmCreate);
    try
      Stream.WriteBuffer(Signature, SizeOf(Signature));
      WriteChunk(Stream, 'IHDR', IHDR);
      WriteChunk(Stream, 'IDAT', Compressed);
      SetLength(Empty, 0);
      WriteChunk(Stream, 'IEND', Empty);
    finally
      Stream.Free;
    end;
    Result := True;
  except
    on E: Exception do ErrorText := E.Message;
  end;
end;

function SaveRGB8PNG(const FileName: string; Width, Height: Integer;
  const Pixels: TByteBuffer; out ErrorText: string): Boolean;
const Signature: array[0..7] of Byte = ($89,$50,$4E,$47,$0D,$0A,$1A,$0A);
var Stream: TFileStream;
    IHDR, Raw, Compressed, Empty: TByteBuffer;
    Y, RawPosition, RowBytes: Integer;
begin
  Result := False;
  ErrorText := '';
  if (Width <= 0) or (Height <= 0) or (Length(Pixels) <> Width * Height * 3) then
  begin
    ErrorText := 'Invalid RGB image dimensions';
    Exit;
  end;
  try
    if ExtractFileDir(FileName) <> '' then ForceDirectories(ExtractFileDir(FileName));
    SetLength(IHDR, 13);
    IHDR[0] := Width shr 24; IHDR[1] := Width shr 16;
    IHDR[2] := Width shr 8; IHDR[3] := Width;
    IHDR[4] := Height shr 24; IHDR[5] := Height shr 16;
    IHDR[6] := Height shr 8; IHDR[7] := Height;
    IHDR[8] := 8; IHDR[9] := 2;
    RowBytes := Width * 3;
    SetLength(Raw, (RowBytes + 1) * Height);
    RawPosition := 0;
    for Y := 0 to Height - 1 do
    begin
      Raw[RawPosition] := 0;
      Inc(RawPosition);
      Move(Pixels[Y * RowBytes], Raw[RawPosition], RowBytes);
      Inc(RawPosition, RowBytes);
    end;
    Compressed := DeflateStored(Raw);
    Stream := TFileStream.Create(FileName, fmCreate);
    try
      Stream.WriteBuffer(Signature, SizeOf(Signature));
      WriteChunk(Stream, 'IHDR', IHDR);
      WriteChunk(Stream, 'IDAT', Compressed);
      SetLength(Empty, 0);
      WriteChunk(Stream, 'IEND', Empty);
    finally
      Stream.Free;
    end;
    Result := True;
  except
    on E: Exception do ErrorText := E.Message;
  end;
end;

end.
