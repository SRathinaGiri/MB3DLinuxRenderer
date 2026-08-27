unit MB3DHeadlessAmbientShadow;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses TypeDefinitions;

function ApplyHeadlessAmbientShadow(const Header: TMandHeader10;
  var Samples: array of TsiLight5; out ShadowedPixels: Integer;
  out MeanOcclusion: Single): Boolean;

implementation

uses Math, MB3DHeadlessUtils;

type
  TAngleDirections = array[0..31] of array[0..1] of Single;
  TAngleMaximum = array[0..31] of SmallInt;
  TAngleMaximumBuffer = array of TAngleMaximum;
  TCardinalBuffer = array of Cardinal;

const
  DirectionCount = 8;
  RadiusCount = 7;
  DirectionX: array[0..DirectionCount - 1] of ShortInt =
    (1, 1, 0, -1, -1, -1, 0, 1);
  DirectionY: array[0..DirectionCount - 1] of ShortInt =
    (0, 1, 1, 1, 0, -1, -1, -1);
  Radius: array[0..RadiusCount - 1] of Integer = (1, 2, 4, 8, 16, 32, 64);

procedure MakeFirstLevel(const Samples: array of TsiLight5;
  var Levels: TCardinalBuffer);
var
  I: Integer;
  EncodedDepth: Cardinal;
begin
  for I := 0 to High(Samples) do
    if Samples[I].Zpos < 32768 then
    begin
      EncodedDepth := Cardinal(Samples[I].RoughZposFine) or
        (Cardinal(Samples[I].Zpos) shl 16);
      Levels[I] := (EncodedDepth and $FFFFFF00) shr 1;
    end
    else
      Levels[I] := 0;
end;

procedure MakeNextLevel(var Levels: TCardinalBuffer; Width, Height,
  Step: Integer);
var
  Scratch: TCardinalBuffer;
  X, Y, A, B, I: Integer;
  V: Cardinal;
begin
  SetLength(Scratch, Max(Width, Height));
  for Y := 0 to Height - 1 do
  begin
    for X := 0 to Width - 1 do Scratch[X] := Levels[Y * Width + X];
    for X := 0 to Width - 1 do
    begin
      A := Max(0, X - Step);
      B := Min(Width - 1, X + Step);
      V := (Scratch[A] + Scratch[B]) shr 1;
      I := Y * Width + X;
      Levels[I] := (Levels[I] + V) shr 1;
    end;
  end;
  for X := 0 to Width - 1 do
  begin
    for Y := 0 to Height - 1 do Scratch[Y] := Levels[Y * Width + X];
    for Y := 0 to Height - 1 do
    begin
      A := Max(0, Y - Step);
      B := Min(Height - 1, Y + Step);
      V := (Scratch[A] + Scratch[B]) shr 1;
      I := Y * Width + X;
      Levels[I] := (Levels[I] + V) shr 1;
    end;
  end;
end;

function ApplyRadial24AmbientShadow(const Header: TMandHeader10;
  var Samples: array of TsiLight5; out ShadowedPixels: Integer;
  out MeanOcclusion: Single): Boolean;
var
  Levels: TCardinalBuffer;
  Angles: TAngleMaximumBuffer;
  Directions: TAngleDirections;
  Width, Height, X, Y, I, Direction, SampleNumber, LevelNumber,
  LevelCount, Step, StepCount, X2, Y2, WLo, WHi, HLo, HHi,
  MirrorWidth, MirrorHeight, AngleValue, MaxPerPass, PassNumber,
  PassCount: Integer;
  Seed: Cardinal;
  ZCorrection, ZMultiplier, ZStartDifference, ZScaleFactor: Double;
  Threshold, BorderMirrorSize, Sit, ZResponse, Scale, MinimumRadius,
  SubPixel, SX, SY, DistanceSquared, Slope, AngleSum,
  TotalOcclusion: Single;
  IsPanorama, Outside: Boolean;
  HeaderCopy: TMandHeader10;
begin
  Result := False;
  ShadowedPixels := 0;
  MeanOcclusion := 0;
  Width := Header.Width;
  Height := Header.Height;
  if (Width < 1) or (Height < 1) or
    (Length(Samples) <> Width * Height) then Exit;

  HeaderCopy := Header;
  CalcPPZvals(HeaderCopy, ZCorrection, ZMultiplier, ZStartDifference);
  if (ZCorrection = 0) or (ZMultiplier = 0) then Exit;
  ZScaleFactor := (Sqr(256 / ZMultiplier + 1) - 1) / ZCorrection;
  Threshold := Max(0.01, Header.sAmbShadowThreshold);
  BorderMirrorSize := Min(Header.bSSAO24BorderMirrorSize * 0.01, 0.9);
  PassCount := Max(1, Header.SSAORcount);
  IsPanorama := Header.bPlanarOptic = 2;

  for Direction := 0 to 31 do
  begin
    SinCos(Direction * Pi / 16, Directions[Direction][0],
      Directions[Direction][1]);
  end;
  I := Round(Sqrt(Sqr(Width) + Sqr(Height)) * 0.5);
  LevelCount := 1;
  Step := 5;
  repeat
    Inc(LevelCount);
    Step := Step shl 1;
  until (LevelCount = 15) or (Step > I);

  SetLength(Levels, Width * Height);
  SetLength(Angles, Width * Height);
  for I := 0 to High(Samples) do Samples[I].AmbShadow := 0;
  WLo := Round(Width * BorderMirrorSize);
  WHi := Width - 1 - WLo;
  HLo := Round(Height * BorderMirrorSize);
  HHi := Height - 1 - HLo;
  MirrorWidth := 2 * (Width - 1);
  MirrorHeight := 2 * (Height - 1);
  Sit := ZScaleFactor / 22000 * 4096;
  if Sit = 0 then Exit;
  MaxPerPass := 16383 div PassCount;

  for PassNumber := 1 to PassCount do
  begin
    MakeFirstLevel(Samples, Levels);
    for I := 0 to High(Angles) do
      for Direction := 0 to 31 do Angles[I][Direction] := -32768;

    for LevelNumber := 1 to LevelCount do
    begin
      ZResponse := Threshold * 0.7 * 4096 / Sit *
        Sqrt(Sqrt(LevelCount / LevelNumber));
      Scale := 1.5 * 32767 /
        (Pi * 32 * Power(ArcTan(Threshold * 0.65 *
        Sqrt(Sqrt(LevelCount))), 0.9)) / PassCount;
      Step := 1 shl (LevelNumber - 1);
      if Step < 2 then
      begin
        MinimumRadius := 1;
        StepCount := 5;
      end
      else
      begin
        MinimumRadius := 3.25 * Step;
        StepCount := 3;
      end;
      SubPixel := (Step - 1) * 0.5;
      { MB3D starts every worker/level with a pseudo-random phase.  A stable
        phase makes headless renders reproducible while retaining its LCG. }
      Seed := $24563487 xor Cardinal(PassNumber * $00100101) xor
        Cardinal(LevelNumber * $00010001);

      for Y := 0 to Height - 1 do
        for X := 0 to Width - 1 do
        begin
          I := Y * Width + X;
          if Samples[I].Zpos >= 32768 then Continue;
          for Direction := 0 to 31 do
          begin
            SX := Directions[Direction][0] * MinimumRadius - SubPixel;
            SY := Directions[Direction][1] * MinimumRadius - SubPixel;
            for SampleNumber := 0 to StepCount - 1 do
            begin
              Seed := Seed * 214013 + 2531011;
              X2 := Round(SX) + Integer((Seed shr 16) and Cardinal(Step - 1));
              Y2 := Round(SY) + Integer((Seed shr 10) and Cardinal(Step - 1));
              DistanceSquared := Sqr(X2) + Sqr(Y2);
              if DistanceSquared <> 0 then
              begin
                Inc(X2, X);
                Inc(Y2, Y);
                Outside := False;
                if IsPanorama then
                begin
                  if X2 < 0 then Inc(X2, Width)
                  else if X2 >= Width then Dec(X2, Width);
                  Outside := (X2 < 0) or (X2 >= Width);
                end
                else if X2 < 0 then
                begin
                  X2 := -X2;
                  Outside := X2 >= WLo;
                end
                else if X2 >= Width then
                begin
                  X2 := MirrorWidth - X2;
                  Outside := X2 < WHi;
                end;
                if not Outside then
                  if Y2 < 0 then
                  begin
                    Y2 := -Y2;
                    Outside := Y2 >= HLo;
                  end
                  else if Y2 >= Height then
                  begin
                    Y2 := MirrorHeight - Y2;
                    Outside := Y2 < HHi;
                  end;
                if not Outside then
                begin
                  Slope := (Integer(Levels[Y2 * Width + X2]) -
                    Integer((Cardinal(Samples[I].RoughZposFine) or
                    (Cardinal(Samples[I].Zpos) shl 16)) and $FFFFFF00) shr 1) /
                    Sqrt(DistanceSquared);
                  AngleValue := Round(Slope * ZResponse * Sit /
                    (ZResponse + Abs(Slope)));
                  if AngleValue > Angles[I][Direction] then
                    Angles[I][Direction] := Min(32767, AngleValue);
                end;
              end;
              SX := SX + Directions[Direction][0] * Step;
              SY := SY + Directions[Direction][1] * Step;
            end;
          end;
          if LevelNumber = LevelCount then
          begin
            AngleSum := 0;
            for Direction := 0 to 31 do
              if Angles[I][Direction] > -32768 then
                AngleSum := AngleSum + ArcTan(Angles[I][Direction] *
                  0.0002441406);
            Inc(Samples[I].AmbShadow, Max(0, Min(MaxPerPass,
              Round(AngleSum * Scale))));
          end;
        end;
      if LevelNumber < LevelCount then
        MakeNextLevel(Levels, Width, Height, 1 shl LevelNumber);
    end;
  end;

  TotalOcclusion := 0;
  for I := 0 to High(Samples) do
  begin
    if Samples[I].AmbShadow > 0 then Inc(ShadowedPixels);
    TotalOcclusion := TotalOcclusion + Samples[I].AmbShadow / 16383;
  end;
  if Length(Samples) > 0 then MeanOcclusion := TotalOcclusion / Length(Samples);
  Result := True;
end;

function ApplyHeadlessAmbientShadow(const Header: TMandHeader10;
  var Samples: array of TsiLight5; out ShadowedPixels: Integer;
  out MeanOcclusion: Single): Boolean;
var X, Y, Direction, RadiusIndex, SampleIndex, NeighbourIndex: Integer;
    NX, NY, DepthDifference, ValidDirections: Integer;
    DirectionOcclusion, Occlusion, TotalOcclusion, Distance,
    DepthScale, Threshold: Single;
begin
  if ((Header.bCalcAmbShadowAutomatic shr 1) and 7) = 4 then
  begin
    Result := ApplyRadial24AmbientShadow(Header, Samples, ShadowedPixels,
      MeanOcclusion);
    Exit;
  end;
  Result := False;
  ShadowedPixels := 0;
  MeanOcclusion := 0;
  if (Header.Width < 1) or (Header.Height < 1) or
    (Length(Samples) <> Header.Width * Header.Height) then Exit;

  { MB3D's GUI ambient-shadow implementations depend on Forms and Windows
    messages.  This portable pass preserves the same buffer contract:
    AmbShadow=0 is unoccluded and AmbShadow=16383 is fully occluded. }
  Threshold := Max(0.01, Abs(Header.sAmbShadowThreshold));
  DepthScale := Threshold * 6;
  TotalOcclusion := 0;
  for Y := 0 to Header.Height - 1 do
    for X := 0 to Header.Width - 1 do
    begin
      SampleIndex := Y * Header.Width + X;
      if Samples[SampleIndex].Zpos >= 32768 then
      begin
        Samples[SampleIndex].AmbShadow := 0;
        Continue;
      end;
      Occlusion := 0;
      ValidDirections := 0;
      for Direction := 0 to DirectionCount - 1 do
      begin
        DirectionOcclusion := 0;
        for RadiusIndex := 0 to RadiusCount - 1 do
        begin
          NX := X + DirectionX[Direction] * Radius[RadiusIndex];
          NY := Y + DirectionY[Direction] * Radius[RadiusIndex];
          if (NX < 0) or (NX >= Header.Width) or
            (NY < 0) or (NY >= Header.Height) then Continue;
          NeighbourIndex := NY * Header.Width + NX;
          if Samples[NeighbourIndex].Zpos >= 32768 then Continue;
          DepthDifference := Integer(Samples[NeighbourIndex].Zpos) -
            Integer(Samples[SampleIndex].Zpos);
          if DepthDifference <= 0 then Continue;
          Distance := Radius[RadiusIndex];
          if (Direction and 1) <> 0 then Distance := Distance * 1.41421356;
          DirectionOcclusion := Max(DirectionOcclusion,
            DepthDifference / (DepthDifference + Distance * DepthScale));
        end;
        Occlusion := Occlusion + DirectionOcclusion;
        Inc(ValidDirections);
      end;
      if ValidDirections > 0 then Occlusion := Occlusion / ValidDirections;
      Occlusion := Sqrt(Max(0, Min(1, Occlusion)));
      Samples[SampleIndex].AmbShadow := Round(Occlusion * 16383);
      if Samples[SampleIndex].AmbShadow > 0 then Inc(ShadowedPixels);
      TotalOcclusion := TotalOcclusion + Occlusion;
    end;
  if Length(Samples) > 0 then MeanOcclusion := TotalOcclusion / Length(Samples);
  Result := True;
end;

end.
