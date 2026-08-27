unit MB3DHeadlessUtils;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses
  TypeDefinitions, Math3D, Types;

type
  TP6 = array[0..6] of Pointer;

procedure SaveHeaderPointers(Header: TPMandHeader10; var Pointers: TP6);
procedure InsertHeaderPointers(Header: TPMandHeader10; const Pointers: TP6);
function CustomFtoStr(const Bytes: array of Byte): AnsiString;
procedure PutStringInCustomF(var Bytes: array of Byte; const Value: AnsiString);
procedure CalcStepWidth(Header: TPMandHeader10);
procedure CalcPPZvals(var Header: TMandHeader10; var ZCorrection, ZMultiplier,
  ZStartDifference: Double);
procedure FastMove(const Source; var Destination; Count: Integer);
procedure MinMaxClip15bit(var s: Single; var w: Word);
function RGBtoSVecScale(const RGB: TRGB; Scale: Single): TSVec;
function ColToSVec(Color: Cardinal; SquareValues: LongBool): TSVec;
function ColAToSVec(Color: Cardinal; SquareValues: LongBool): TSVec;
function ColToSVecNoScale(Color: Cardinal): TSVec;
function RGBColToSVecNoScaleSQR(const RGB: TRGB): TSVec;
function RGBColToSVecNoScale(const RGB: TRGB): TSVec;
function DVecFromLightPos(var Light: TLight8): TVec3D;
procedure GetTilingInfosFromHeader(Header: TPMandHeader10; var TileRect: TRect;
  var Crop: Integer);
function GetTileSize(Header: TPMandHeader10): TPoint;

var
  SupportSSE2: Boolean = True;
  PAligned16: Pointer = nil;

implementation

uses
  Math;

var
  FormulaConstantBuffer: array[0..511] of Byte;

procedure SaveHeaderPointers(Header: TPMandHeader10; var Pointers: TP6);
var
  Index: Integer;
begin
  for Index := 0 to 5 do Pointers[Index] := Header.PHCustomF[Index];
  Pointers[6] := Header.PCFAddon;
end;

procedure InsertHeaderPointers(Header: TPMandHeader10; const Pointers: TP6);
var
  Index: Integer;
begin
  for Index := 0 to 5 do Header.PHCustomF[Index] := Pointers[Index];
  Header.PCFAddon := Pointers[6];
end;

function CustomFtoStr(const Bytes: array of Byte): AnsiString;
var
  Index: Integer;
begin
  Result := '';
  Index := 0;
  while (Index <= High(Bytes)) and (Index < 32) and (Bytes[Index] <> 0) do
  begin
    Result := Result + AnsiChar(Bytes[Index]);
    Inc(Index);
  end;
end;

procedure PutStringInCustomF(var Bytes: array of Byte; const Value: AnsiString);
var
  Index, Limit: Integer;
begin
  if Length(Bytes) = 0 then Exit;
  FillChar(Bytes[0], Length(Bytes), 0);
  Limit := Min(Length(Value), Min(31, Length(Bytes) - 1));
  for Index := 1 to Limit do Bytes[Index - 1] := Ord(Value[Index]);
end;

procedure CalcStepWidth(Header: TPMandHeader10);
begin
  with Header^ do dStepWidth := 2.1345 / (dZoom * Width);
end;

procedure CalcPPZvals(var Header: TMandHeader10; var ZCorrection, ZMultiplier,
  ZStartDifference: Double);
begin
  CalcStepWidth(@Header);
  ZCorrection := Sin(Max(Header.dFOVy * Pid180, 1.0) / Header.Height);
  ZMultiplier := 32767 * 256.0 /
    (Sqrt((Header.dZend - Header.dZstart) * ZCorrection /
      Header.dStepWidth + 1) - 0.999999999);
  ZStartDifference := Header.dZstart - Header.dZmid;
end;

procedure FastMove(const Source; var Destination; Count: Integer);
begin
  System.Move(Source, Destination, Count);
end;

procedure MinMaxClip15bit(var s: Single; var w: Word);
begin
  if s <= 0 then
    w := 0
  else if s >= 32767 then
    w := 32767
  else
    w := Round(s);
end;

function RGBtoSVecScale(const RGB: TRGB; Scale: Single): TSVec;
begin
  Result[0] := RGB[0] * Scale;
  Result[1] := RGB[1] * Scale;
  Result[2] := RGB[2] * Scale;
  Result[3] := 0;
end;

function ColToSVec(Color: Cardinal; SquareValues: LongBool): TSVec;
begin
  if SquareValues then
  begin
    Result[0] := Sqr(Color and $FF) * 0.0000153787;
    Result[1] := Sqr((Color shr 8) and $FF) * 0.0000153787;
    Result[2] := Sqr((Color shr 16) and $FF) * 0.0000153787;
  end
  else
  begin
    Result[0] := (Color and $FF) * s1d255;
    Result[1] := ((Color shr 8) and $FF) * s1d255;
    Result[2] := ((Color shr 16) and $FF) * s1d255;
  end;
  Result[3] := 0;
end;

function ColAToSVec(Color: Cardinal; SquareValues: LongBool): TSVec;
begin
  Result := ColToSVec(Color, SquareValues);
  if SquareValues then
    Result[3] := Sqr(Color shr 24) * 0.0000153787
  else
    Result[3] := (Color shr 24) * s1d255;
end;

function ColToSVecNoScale(Color: Cardinal): TSVec;
begin
  Result[0] := Color and $FF;
  Result[1] := (Color shr 8) and $FF;
  Result[2] := (Color shr 16) and $FF;
  Result[3] := 0;
end;

function RGBColToSVecNoScaleSQR(const RGB: TRGB): TSVec;
begin
  Result[0] := Sqr(Integer(RGB[0])) * s1d255;
  Result[1] := Sqr(Integer(RGB[1])) * s1d255;
  Result[2] := Sqr(Integer(RGB[2])) * s1d255;
  Result[3] := 0;
end;

function RGBColToSVecNoScale(const RGB: TRGB): TSVec;
begin
  Result[0] := RGB[0];
  Result[1] := RGB[1];
  Result[2] := RGB[2];
  Result[3] := 0;
end;

function DVecFromLightPos(var Light: TLight8): TVec3D;
begin
  Result[0] := D7BtoDouble(Light.LXpos);
  Result[1] := D7BtoDouble(Light.LYpos);
  Result[2] := D7BtoDouble(Light.LZpos);
end;

procedure GetTilingInfosFromHeader(Header: TPMandHeader10; var TileRect: TRect;
  var Crop: Integer);
var
  Options: Integer;
  TileCount, TilePosition, TileSize: TPoint;
begin
  Options := Header.TilingOptions;
  Crop := Max(1, (Options shr 28) and 3);
  TileCount := Point(Options and $7F, (Options shr 7) and $7F);
  TilePosition := Point((Options shr 14) and $7F, (Options shr 21) and $7F);
  TileSize := Point(Header.Width div TileCount.X, Header.Height div TileCount.Y);
  TileRect := Rect(TilePosition.X * TileSize.X - Crop,
    TilePosition.Y * TileSize.Y - Crop,
    (TilePosition.X + 1) * TileSize.X + Crop - 1,
    (TilePosition.Y + 1) * TileSize.Y + Crop - 1);
end;

function GetTileSize(Header: TPMandHeader10): TPoint;
var
  TileCount: TPoint;
  Crop: Integer;
begin
  if Header.TilingOptions = 0 then
    Result := Point(Header.Width, Header.Height)
  else
  begin
    Crop := Max(1, (Header.TilingOptions shr 28) and 3);
    TileCount := Point(Header.TilingOptions and $7F,
      (Header.TilingOptions shr 7) and $7F);
    Result := Point(Header.Width div TileCount.X + 2 * Crop,
      Header.Height div TileCount.Y + 2 * Crop);
  end;
  Result.X := Max(1, Min(30000, Result.X));
  Result.Y := Max(1, Min(30000, Result.Y));
end;

procedure InitializeFormulaConstants;
begin
  PAligned16 := Pointer((PtrUInt(@FormulaConstantBuffer[0]) + 127) and not PtrUInt($F));
  PDouble(PtrUInt(PAligned16) - 8)^ := 0.5;
  PInt64(PAligned16)^ := $7FFFFFFFFFFFFFFF;
  PInt64(PtrUInt(PAligned16) + 8)^ := $7FFFFFFFFFFFFFFF;
  PDouble(PtrUInt(PAligned16) + 16)^ := -2.0;
  PDouble(PtrUInt(PAligned16) + 24)^ := 1e-100;
  PDouble(PtrUInt(PAligned16) + 32)^ := 1.0;
  PDouble(PtrUInt(PAligned16) + 40)^ := 1.0;
  PDouble(PtrUInt(PAligned16) + 48)^ := -1.0;
  PDouble(PtrUInt(PAligned16) + 56)^ := -1.0;
  PDouble(PtrUInt(PAligned16) + 64)^ := 2.0;
  PDouble(PtrUInt(PAligned16) + 72)^ := 2.0;
  PInt64(PtrUInt(PAligned16) + 80)^ := Int64($8000000000000000);
  PInt64(PtrUInt(PAligned16) + 88)^ := Int64($8000000000000000);
  PDouble(PtrUInt(PAligned16) + 96)^ := -1.0;
  PDouble(PtrUInt(PAligned16) + 104)^ := 2.0;
  PDouble(PtrUInt(PAligned16) + 112)^ := 0.5;
  PDouble(PtrUInt(PAligned16) + 120)^ := 3.0;
  PDouble(PtrUInt(PAligned16) + 128)^ := 4.0;
  PDouble(PtrUInt(PAligned16) + 136)^ := 5.0;
  PDouble(PtrUInt(PAligned16) + 144)^ := 6.0;
  PDouble(PtrUInt(PAligned16) + 152)^ := 7.0;
  PDouble(PtrUInt(PAligned16) + 160)^ := 8.0;
  PDouble(PtrUInt(PAligned16) + 168)^ := 10.0;
  PDouble(PtrUInt(PAligned16) + 176)^ := 15.0;
  PDouble(PtrUInt(PAligned16) + 184)^ := 21.0;
  PDouble(PtrUInt(PAligned16) + 192)^ := 28.0;
  PDouble(PtrUInt(PAligned16) + 200)^ := 35.0;
  PDouble(PtrUInt(PAligned16) + 208)^ := 70.0;
end;

initialization
  InitializeFormulaConstants;

end.
