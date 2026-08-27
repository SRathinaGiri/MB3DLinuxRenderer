unit MB3DAnimationHeaderInterpolation;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses
  MB3DAnimationModel;

procedure InterpolateMB3DAnimationV5Header(const FromHeader, ToHeader: TMB3DAnimationV5Header;
  const Position: Double; out InterpolatedHeader: TMB3DAnimationV5Header);

implementation

uses
  Math, SysUtils;

const
  IntegerOffsets: array[0..1] of Integer = (12, 135);
  DoubleOffsets: array[0..12] of Integer =
    (20, 28, 36, 44, 52, 108, 191, 199, 207, 215, 346, 354, 362);
  AngleOffsets: array[0..2] of Integer = (60, 68, 76);
  SingleOffsets: array[0..18] of Integer =
    (116, 120, 164, 168, 172, 177, 182, 226, 230, 234, 238, 242,
     319, 332, 338, 370, 374, 378, 410);
  LogDoubleOffsets: array[0..1] of Integer = (84, 92);

function ClampPosition(const Position: Double): Double;
begin
  Result := Position;
  if Result < 0 then Result := 0;
  if Result > 1 then Result := 1;
end;

function ReadInteger(const Data: TMB3DAnimationV5Header; const Offset: Integer): Integer;
begin
  Move(Data[Offset], Result, SizeOf(Result));
end;

function ReadSingle(const Data: TMB3DAnimationV5Header; const Offset: Integer): Single;
begin
  Move(Data[Offset], Result, SizeOf(Result));
end;

function ReadDouble(const Data: TMB3DAnimationV5Header; const Offset: Integer): Double;
begin
  Move(Data[Offset], Result, SizeOf(Result));
end;

procedure WriteInteger(var Data: TMB3DAnimationV5Header; const Offset, Value: Integer);
begin
  Move(Value, Data[Offset], SizeOf(Value));
end;

procedure WriteSingle(var Data: TMB3DAnimationV5Header; const Offset: Integer; const Value: Single);
begin
  Move(Value, Data[Offset], SizeOf(Value));
end;

procedure WriteDouble(var Data: TMB3DAnimationV5Header; const Offset: Integer; const Value: Double);
begin
  Move(Value, Data[Offset], SizeOf(Value));
end;

procedure InterpolateMB3DAnimationV5Header(const FromHeader, ToHeader: TMB3DAnimationV5Header;
  const Position: Double; out InterpolatedHeader: TMB3DAnimationV5Header);
var
  T, FromValue, ToValue, Delta: Double;
  Index: Integer;
begin
  InterpolatedHeader := FromHeader;
  T := ClampPosition(Position);
  for Index := Low(IntegerOffsets) to High(IntegerOffsets) do
    WriteInteger(InterpolatedHeader, IntegerOffsets[Index], Round(
      ReadInteger(FromHeader, IntegerOffsets[Index]) * (1 - T) +
      ReadInteger(ToHeader, IntegerOffsets[Index]) * T));
  for Index := Low(DoubleOffsets) to High(DoubleOffsets) do
    WriteDouble(InterpolatedHeader, DoubleOffsets[Index],
      ReadDouble(FromHeader, DoubleOffsets[Index]) * (1 - T) +
      ReadDouble(ToHeader, DoubleOffsets[Index]) * T);
  for Index := Low(SingleOffsets) to High(SingleOffsets) do
    WriteSingle(InterpolatedHeader, SingleOffsets[Index],
      ReadSingle(FromHeader, SingleOffsets[Index]) * (1 - T) +
      ReadSingle(ToHeader, SingleOffsets[Index]) * T);
  for Index := Low(LogDoubleOffsets) to High(LogDoubleOffsets) do
  begin
    FromValue := Max(1e-10, ReadDouble(FromHeader, LogDoubleOffsets[Index]));
    ToValue := Max(1e-10, ReadDouble(ToHeader, LogDoubleOffsets[Index]));
    WriteDouble(InterpolatedHeader, LogDoubleOffsets[Index],
      Exp(Ln(FromValue) * (1 - T) + Ln(ToValue) * T));
  end;
  for Index := Low(AngleOffsets) to High(AngleOffsets) do
  begin
    FromValue := ReadDouble(FromHeader, AngleOffsets[Index]);
    ToValue := ReadDouble(ToHeader, AngleOffsets[Index]);
    Delta := ToValue - FromValue;
    while Delta > 180 do Delta := Delta - 360;
    while Delta < -180 do Delta := Delta + 360;
    WriteDouble(InterpolatedHeader, AngleOffsets[Index], FromValue + Delta * T);
  end;
end;

end.
