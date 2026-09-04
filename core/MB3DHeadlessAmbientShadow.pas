unit MB3DHeadlessAmbientShadow;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses TypeDefinitions;

type
  THeadlessAmbientMode = (hamAuto, hamClassic24, hamRadial24, hamOff);

function ApplyHeadlessAmbientShadow(const Header: TMandHeader10;
  var Samples: array of TsiLight5; out ShadowedPixels: Integer;
  out MeanOcclusion: Single; AmbientMode: THeadlessAmbientMode;
  out AppliedMode: string): Boolean; overload;

function ApplyHeadlessAmbientShadow(const Header: TMandHeader10;
  var Samples: array of TsiLight5; out ShadowedPixels: Integer;
  out MeanOcclusion: Single): Boolean; overload;

implementation

uses Math, MB3DHeadlessUtils;

type
  TAngleDirections = array[0..31] of array[0..1] of Single;
  TAngleMaximum = array[0..31] of SmallInt;
  TAngleMaximumBuffer = array of TAngleMaximum;
  TCardinalBuffer = array of Cardinal;
  TClassicAngleMaximum4 = array[0..35, 0..3] of Single;

function ClassicEncodedDepth(const Sample: TsiLight5): Integer;
begin
  Result := Integer((Cardinal(Sample.RoughZposFine) or
    (Cardinal(Sample.Zpos) shl 16)) shr 8);
end;

function FastIntArcTan2(Y, X: Integer): Integer;
begin
  if X = 0 then
    Result := Integer(Y >= 0) * 16 + 8
  else if Y = 0 then
    Result := Integer(X >= 0) * 16
  else if Y < 0 then
  begin
    if X < 0 then
    begin
      if X >= Y then Result := 7 - (X * 4) div Y
      else Result := (Y * 4) div X;
    end
    else
    begin
      if -Y < X then Result := 15 + (Y * 4) div X
      else Result := 8 - (X * 4) div Y;
    end;
  end
  else
  begin
    if X >= 0 then
    begin
      if X > Y then Result := 16 + (Y * 4) div X
      else Result := 23 - (X * 4) div Y;
    end
    else
    begin
      if Y < -X then Result := 31 + (Y * 4) div X
      else Result := 24 - (X * 4) div Y;
    end;
  end;
end;

function BuildClassicATLevels(const Samples: array of TsiLight5;
  Width, Height: Integer; var Levels: TATlevel; var CorrMul: Single;
  var ZSub: Integer): Integer;
const
  NeighbourOffsetX: array[0..7] of ShortInt = (-1, 0, 1, -1, 1, -1, 0, 1);
  NeighbourOffsetY: array[0..7] of ShortInt = (-1, -1, -1, 0, 0, 1, 1, 1);
var
  X, Y, I, N, LevelIndex, Step, Step2, NeighbourIndex: Integer;
  MinZ, MaxZ, MaxNeighbour, CenterValue, LeftValue, RightValue,
  UpValue, DownValue, LeftIndex, RightIndex, UpIndex, DownIndex,
  RowBase: Integer;
  Scale: Single;
begin
  try
    Result := 1;
    X := Width div 16;
    repeat
      Inc(Result);
      X := X shr 1;
    until (Result = 8) or (X < 4);
    for X := 1 to Result + 1 do SetLength(Levels[X], Width * Height);

    MinZ := 32767;
    MaxZ := 0;
    for I := 0 to High(Samples) do
      if Samples[I].Zpos < 32768 then
      begin
        if Samples[I].Zpos > MaxZ then MaxZ := Samples[I].Zpos;
        if Samples[I].Zpos < MinZ then MinZ := Samples[I].Zpos;
      end;
    if MaxZ < MinZ then
    begin
      MaxZ := 32768;
      MinZ := 0;
    end
    else
      Inc(MaxZ);
    Scale := 128 / (MaxZ - MinZ);
    ZSub := MinZ shl 8;
    CorrMul := Scale;
    for I := 0 to High(Samples) do
      if Samples[I].Zpos < 32768 then
        Levels[1][I] := Round((ClassicEncodedDepth(Samples[I]) - ZSub) *
          Scale)
      else
        Levels[1][I] := 0;

    for Y := 1 to Height - 2 do
      for X := 1 to Width - 2 do
      begin
        I := Y * Width + X;
        CenterValue := Levels[1][I];
        MaxNeighbour := 0;
        for N := 0 to 7 do
        begin
          NeighbourIndex := (Y + NeighbourOffsetY[N]) * Width + X +
            NeighbourOffsetX[N];
          if Levels[1][NeighbourIndex] >= CenterValue then
          begin
            MaxNeighbour := 0;
            Break;
          end;
          if Levels[1][NeighbourIndex] > MaxNeighbour then
            MaxNeighbour := Levels[1][NeighbourIndex];
        end;
        if MaxNeighbour > 0 then Levels[1][I] := MaxNeighbour + 1;
      end;

    Step := 1;
    for LevelIndex := 2 to Result do
    begin
      Step2 := Step * 2;
      Move(Levels[LevelIndex - 1][0], Levels[LevelIndex][0],
        Width * Height * SizeOf(Word));
      for Y := 0 to Height - 1 do
      begin
        RowBase := Y * Width;
        for X := 0 to Width - 1 do
        begin
          LeftIndex := Max(0, X - Step2);
          RightIndex := Min(Width - 1, X + Step2);
          CenterValue := Levels[LevelIndex - 1][RowBase + X];
          LeftValue := Levels[LevelIndex - 1][RowBase + LeftIndex];
          RightValue := Levels[LevelIndex - 1][RowBase + RightIndex];
          Levels[LevelIndex + 1][RowBase + X] := (CenterValue + 1 +
            ((LeftValue + RightValue + 1) shr 1)) shr 1;
        end;
      end;
      for X := 0 to Width - 1 do
        for Y := 0 to Height - 1 do
        begin
          UpIndex := Max(0, Y - Step2);
          DownIndex := Min(Height - 1, Y + Step2);
          CenterValue := Levels[LevelIndex + 1][Y * Width + X];
          UpValue := Levels[LevelIndex + 1][UpIndex * Width + X];
          DownValue := Levels[LevelIndex + 1][DownIndex * Width + X];
          Levels[LevelIndex][Y * Width + X] := (CenterValue + 1 +
            ((UpValue + DownValue + 1) shr 1)) shr 1;
        end;
      Step := Step * 2;
    end;
  except
    Result := 0;
  end;
end;

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

function ApplyClassic24AmbientShadow(const Header: TMandHeader10;
  var Samples: array of TsiLight5; out ShadowedPixels: Integer;
  out MeanOcclusion: Single): Boolean;
const
  Sentinel = $FFFFFF;
var
  Levels: TATlevel;
  AngMax: TClassicAngleMaximum4;
  ZP4: array[0..3] of Integer;
  Width, Height, X, Y, X2, Y2, YA, XA, XE, YE, XA2, XA2T,
  MaxRadius, MinRadius, Step, XT, YA2, ID4C, X3, ID4L,
  LevelIndex, MinRadiusSquared, MaxRadiusSquared, AngleCenter,
  RadiusSquared, AngleWidth, II, OffsetIndex, LevelCount, ZSub,
  PixelIndex: Integer;
  CorrMul, DepthStep, InvRadius, LevelRadius, ThresholdScaled, Scale,
  ThresholdLevel, Slope, SumAngles, TotalOcclusion: Single;
  Do4, Do4Level, MultiAngle: Boolean;
  ZCorrection, ZMultiplier, ZStartDifference, ZScaleFactor: Double;
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
  LevelCount := BuildClassicATLevels(Samples, Width, Height, Levels,
    CorrMul, ZSub);
  if LevelCount < 1 then Exit;
  DepthStep := ZScaleFactor / (CorrMul * 256);
  if DepthStep = 0 then Exit;
  ThresholdScaled := Max(0.01, Header.sAmbShadowThreshold) / DepthStep;
  Scale := 1.35 * 32767 / (Pi * 32 *
    Power(ArcTan(Max(0.01, Header.sAmbShadowThreshold) *
    Sqrt(Sqrt(LevelCount))), 0.8));

  for PixelIndex := 0 to High(Samples) do Samples[PixelIndex].AmbShadow := 0;
  TotalOcclusion := 0;
  for Y := 0 to Height - 1 do
  begin
    X := 0;
    while X < Width do
    begin
      PixelIndex := Y * Width + X;
      if Samples[PixelIndex].Zpos < 32768 then
        ZP4[0] := Round((ClassicEncodedDepth(Samples[PixelIndex]) - ZSub) *
          CorrMul)
      else
        ZP4[0] := 32768;
      Do4 := X < Width - 3;
      if Do4 then
      begin
        for X2 := 1 to 3 do
          if Samples[PixelIndex + X2].Zpos < 32768 then
            ZP4[X2] := Round((ClassicEncodedDepth(Samples[PixelIndex + X2]) -
              ZSub) * CorrMul)
          else
            ZP4[X2] := 32768;
        ID4C := 3;
      end
      else
        ID4C := 0;

      if (ZP4[0] < 32768) or (Do4 and
        (Integer(ZP4[1]) + ZP4[2] + ZP4[3] < 98304)) then
      begin
        for X2 := 0 to 35 do
        begin
          AngMax[X2, 0] := -1e10;
          if Do4 then
          begin
            AngMax[X2, 1] := -1e10;
            AngMax[X2, 2] := -1e10;
            AngMax[X2, 3] := -1e10;
          end;
        end;

        MaxRadius := 0;
        MinRadius := 0;
        for LevelIndex := 1 to LevelCount do
        begin
          Step := 1 shl (LevelIndex - 1);
          LevelRadius := Sqrt(Step) * 5;
          MaxRadius := MaxRadius + 4 * Step;
          MaxRadiusSquared := MaxRadius * MaxRadius;
          MinRadiusSquared := MinRadius * MinRadius;
          MultiAngle := Round(LevelRadius / (MinRadius + 1)) > 0;
          ThresholdLevel := ThresholdScaled * Sqrt(Sqrt(LevelCount /
            LevelIndex));

          YA := -MaxRadius;
          if YA + Y < 0 then
          begin
            YA2 := YA;
            while YA2 + Y < 0 do Inc(YA2, Step);
            if YA2 + Y >= Height then YA2 := Height - Y - 1;
            YA := -Y;
            if YA = YA2 then YA2 := Sentinel;
          end
          else
            YA2 := Sentinel;
          if Y + MaxRadius >= Height then YE := Height - Y - 1
          else YE := MaxRadius;

          Do4Level := Do4 and (X >= MaxRadius) and
            (X < Width - MaxRadius - 3);
          if Do4Level then ID4L := ID4C else ID4L := 0;
          XA := -MaxRadius;
          XA2 := Sentinel;
          XE := MaxRadius;

          Y2 := YA;
          repeat
            if Y2 > YA2 then
            begin
              Y2 := YA2;
              YA2 := Sentinel;
            end;

            OffsetIndex := 0;
            repeat
              if not Do4Level then
              begin
                X2 := X + OffsetIndex;
                XA := -MaxRadius;
                if XA + X2 < 0 then
                begin
                  XA2 := XA;
                  while XA2 + X2 < 0 do Inc(XA2, Step);
                  if XA2 + X2 >= Width then XA2 := Width - X2 - 1;
                  XA := -X2;
                  if XA = XA2 then XA2 := Sentinel;
                end
                else
                  XA2 := Sentinel;
                if X2 + MaxRadius >= Width then XE := Width - X2 - 1
                else XE := MaxRadius;
              end;

              X2 := XA;
              XA2T := XA2;
              repeat
                if X2 > XA2T then
                begin
                  Inc(X2, XA2T - X2);
                  X2 := XA2T;
                  XA2T := Sentinel;
                end;
                RadiusSquared := Y2 * Y2 + X2 * X2;
                if (RadiusSquared > MinRadiusSquared) and
                  (RadiusSquared <= MaxRadiusSquared) then
                begin
                  AngleCenter := FastIntArcTan2(Y2, X2);
                  InvRadius := 1 / Sqrt(RadiusSquared);
                  if MultiAngle then
                  begin
                    AngleWidth := Round(LevelRadius * InvRadius);
                    for X3 := 0 to ID4L do
                    begin
                      Slope := (Integer(Levels[LevelIndex][X + X2 +
                        OffsetIndex + X3 + (Y + Y2) * Width]) -
                        ZP4[X3 + OffsetIndex]) * InvRadius;
                      if Slope > ThresholdLevel then Slope := ThresholdLevel;
                      for II := 0 to AngleWidth do
                        if AngMax[(AngleCenter - (AngleWidth shr 1) + II) and
                          31, X3 + OffsetIndex] < Slope then
                          AngMax[(AngleCenter - (AngleWidth shr 1) + II) and
                            31, X3 + OffsetIndex] := Slope;
                    end;
                  end
                  else
                    for X3 := OffsetIndex to OffsetIndex + ID4L do
                    begin
                      Slope := (Integer(Levels[LevelIndex][X + X2 + X3 +
                        (Y + Y2) * Width]) - ZP4[X3]) * InvRadius;
                      if Slope > ThresholdLevel then Slope := ThresholdLevel;
                      if AngMax[AngleCenter, X3] < Slope then
                        AngMax[AngleCenter, X3] := Slope;
                    end;
                end;
                XT := X2;
                Inc(X2, Step);
                if (X2 > XE) and (XT < XE) then X2 := XE;
              until X2 > XE;

              Inc(OffsetIndex);
            until Do4Level or (OffsetIndex > ID4C);

            Inc(Y2, Step);
            if (Y2 > YE) and (Y2 - Step < YE) then Y2 := YE;
          until Y2 > YE;

          MinRadius := MaxRadius;
        end;

        for X3 := 0 to ID4C do
        begin
          if X + X3 >= Width then Break;
          for X2 := 0 to 3 do
            if AngMax[X2 + 32, X3] > AngMax[X2, X3] then
              AngMax[X2, X3] := AngMax[X2 + 32, X3];
          SumAngles := 0;
          for X2 := 0 to 31 do
            if AngMax[X2, X3] > -1e9 then
              SumAngles := SumAngles + ArcTan(AngMax[X2, X3] * DepthStep);
          PixelIndex := Y * Width + X + X3;
          Samples[PixelIndex].AmbShadow := Max(0, Min(16383,
            Round(SumAngles * Scale)));
          if Samples[PixelIndex].AmbShadow > 0 then Inc(ShadowedPixels);
        end;
      end;

      if Do4 then Inc(X, 4) else Inc(X);
    end;
  end;

  for PixelIndex := 0 to High(Samples) do
    TotalOcclusion := TotalOcclusion + Samples[PixelIndex].AmbShadow / 16383;
  if Length(Samples) > 0 then MeanOcclusion := TotalOcclusion / Length(Samples);
  Result := True;
end;

function ApplyHeadlessAmbientShadow(const Header: TMandHeader10;
  var Samples: array of TsiLight5; out ShadowedPixels: Integer;
  out MeanOcclusion: Single; AmbientMode: THeadlessAmbientMode;
  out AppliedMode: string): Boolean;
var X, Y, Direction, RadiusIndex, SampleIndex, NeighbourIndex: Integer;
    NX, NY, DepthDifference, ValidDirections: Integer;
    DirectionOcclusion, Occlusion, TotalOcclusion, Distance,
    DepthScale, Threshold: Single;
begin
  AppliedMode := 'disabled';
  if AmbientMode = hamOff then
  begin
    ShadowedPixels := 0;
    MeanOcclusion := 0;
    for SampleIndex := 0 to High(Samples) do Samples[SampleIndex].AmbShadow := 0;
    Result := True;
    Exit;
  end;
  if AmbientMode = hamClassic24 then
  begin
    Result := ApplyClassic24AmbientShadow(Header, Samples, ShadowedPixels,
      MeanOcclusion);
    if Result then AppliedMode := 'mb3d-24bit-classic';
    Exit;
  end;
  if AmbientMode = hamRadial24 then
  begin
    Result := ApplyRadial24AmbientShadow(Header, Samples, ShadowedPixels,
      MeanOcclusion);
    if Result then AppliedMode := 'mb3d-24bit-radial';
    Exit;
  end;
  if (Header.bCalcAmbShadowAutomatic and 12) in [4, 8] then
  begin
    Result := ApplyRadial24AmbientShadow(Header, Samples, ShadowedPixels,
      MeanOcclusion);
    if Result then AppliedMode := 'mb3d-24bit-radial';
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
  AppliedMode := 'portable-horizon';
  Result := True;
end;

function ApplyHeadlessAmbientShadow(const Header: TMandHeader10;
  var Samples: array of TsiLight5; out ShadowedPixels: Integer;
  out MeanOcclusion: Single): Boolean;
var
  AppliedMode: string;
begin
  Result := ApplyHeadlessAmbientShadow(Header, Samples, ShadowedPixels,
    MeanOcclusion, hamAuto, AppliedMode);
end;

end.
