unit MB3DHeadlessShading;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses TypeDefinitions, MB3DPortablePNG;

procedure ShadeMB3DFrame(var Header: TMandHeader10; const LightVals: TLightVals;
  const Samples: array of TsiLight5; CalculateHardShadows: Boolean;
  out Pixels: TByteBuffer;
  out DirectionalLights, SkippedLights, DepthFoggedPixels,
  DynamicFoggedPixels: Integer; out MeanDepthFog, MeanDynamicFog: Single);

implementation

uses Math, Math3D, HeaderTrafos, MB3DHeadlessUtils;

type
  TFloatRGB = array[0..2] of Single;
  TLightInfo = record
    Direction: TSVec;
    Color: TFloatRGB;
    ShadowMask: Integer;
    HardShadowEnabled: Boolean;
    HardShadowCalculated: Boolean;
    DiffuseFunction: Integer;
    SpecularPower: Integer;
  end;

var
  DiffCosTabNsmall: array[0..7, 0..127] of Single;
  CosTablesReady: Boolean = False;

procedure EnsureCosTables;
var
  I, J, K, L: Integer;
  D: Double;
  E: Extended;
  TmpTabSmall: array[0..127] of Single;
begin
  if CosTablesReady then Exit;
  for I := 0 to 127 do
  begin
    D := 1 - (I - 2) / 60;
    if D > 0.15 then DiffCosTabNsmall[0][I] := (D - 0.08) * 1.0869565
    else if D <= 0 then DiffCosTabNsmall[0][I] := 0
    else DiffCosTabNsmall[0][I] := Power(D, Max(1, (0.505 - D) * 3.8));
    DiffCosTabNsmall[1][I] := Sqr(Clamp0D(D));
    DiffCosTabNsmall[2][I] := D * s05 + s05;
    DiffCosTabNsmall[3][I] := Sqr(D * s05 + s05);
  end;
  for K := 0 to 3 do
  begin
    for J := 0 to 127 do TmpTabSmall[J] := Sqrt(Max0S(DiffCosTabNsmall[K][J]));
    for J := 0 to 127 do
    begin
      E := 0;
      for I := 0 to 60 do
      begin
        L := Abs(J + I - 30);
        if L < 128 then E := E + TmpTabSmall[L];
      end;
      DiffCosTabNsmall[K + 4][J] := Sqr(E * 0.011 + Sqr(E * 0.007));
    end;
  end;
  CosTablesReady := True;
end;

function HeadlessGetCosTabVal(Tnr: Integer; const DotP, Rough: Single): Single;
var
  IP: Integer;
  T: Single;
  W: TSVec;
  P1: TPSingleArray;
begin
  if Tnr < 0 then Tnr := 0
  else if Tnr > 3 then Tnr := 3;
  T := 62 - 60 * DotP;
  IP := Trunc(T) - 1;
  if IP < 0 then
  begin
    IP := 0;
    T := 0;
  end
  else if IP > 124 then
  begin
    IP := 124;
    T := 1;
  end
  else T := Frac(T);
  W := MakeSplineCoeff(T);
  P1 := @DiffCosTabNsmall[Tnr][IP];
  Result := P1[0] * W[0] + P1[1] * W[1] + P1[2] * W[2] + P1[3] * W[3];
  P1 := @DiffCosTabNsmall[Tnr + 4][IP];
  Result := Result + Rough * (P1[0] * W[0] + P1[1] * W[1] +
    P1[2] * W[2] + P1[3] * W[3] - Result);
end;

function DotOf2VecNormalize(const Norm, Light, View: TSVec): Single;
var D2: Single;
begin
  D2 := 2 * (Norm[0] * View[0] + Norm[1] * View[1] +
    Norm[2] * View[2]);
  Result := Light[0] * (View[0] - Norm[0] * D2) +
    Light[1] * (View[1] - Norm[1] * D2) +
    Light[2] * (View[2] - Norm[2] * D2);
end;

procedure CalcViewVecForPixel(var ViewVec: TSVec; var Header: TMandHeader10;
  X, Y: Integer);
var
  CX, CY, FOVY, Aspect, D: Double;
begin
  if (Header.bPlanarOptic and 3) = 2 then
  begin
    FOVY := Pi;
    Aspect := 2;
  end
  else
  begin
    FOVY := Header.dFOVy * Pid180;
    Aspect := Header.Width / Header.Height;
  end;
  CX := (CalcXoff(@Header) - (X + 1) / Header.Width) * FOVY * Aspect;
  CY := (Y / Header.Height - 0.5) * FOVY;
  if (Header.bPlanarOptic and 3) = 1 then
  begin
    ViewVec[0] := -CX;
    ViewVec[1] := CY;
    D := MinCS(1.5, MaxCS(s001, FOVY * s05));
    ViewVec[2] := Cos(D) * D / Sin(D);
    NormaliseSVectorVar(ViewVec);
  end
  else if (Header.bPlanarOptic and 3) = 2 then
    BuildViewVectorSphereFOV(CY, CX, @ViewVec)
  else
    BuildViewVectorFOV(CY, CX, @ViewVec);
end;

procedure CalcObjectColors(const LightVals: TLightVals; const Sample: TsiLight5;
  ZPosition: Single; IsInside: Boolean; out DiffuseColor,
  SpecularColor: TSVec);
var
  ColorIndex, LowerIndex, UpperIndex: Integer;
  Weight: Single;
begin
  if IsInside then
  begin
    ColorIndex := Round(((Sample.SIgradient - LightVals.sCiStart) *
      LightVals.sCimul + LightVals.sColZmul * ZPosition) * 16384);
    if LightVals.bColCycling then ColorIndex := ColorIndex and 32767
    else
    begin
      if ColorIndex < 0 then
      begin
        DiffuseColor := LightVals.PLValigned.ColInt[0];
        SpecularColor[0] := DiffuseColor[3];
        SpecularColor[1] := DiffuseColor[3];
        SpecularColor[2] := DiffuseColor[3];
        SpecularColor[3] := DiffuseColor[3];
        DiffuseColor[3] := 0;
        Exit;
      end
      else if ColorIndex > LightVals.IColPos[3] then
      begin
        DiffuseColor := LightVals.PLValigned.ColInt[3];
        SpecularColor[0] := DiffuseColor[3];
        SpecularColor[1] := DiffuseColor[3];
        SpecularColor[2] := DiffuseColor[3];
        SpecularColor[3] := DiffuseColor[3];
        DiffuseColor[3] := 0;
        Exit;
      end;
    end;
    UpperIndex := 1;
    while (UpperIndex < 4) and
      (LightVals.IColPos[UpperIndex] < ColorIndex) do Inc(UpperIndex);
    if LightVals.bNoColIpol then
      DiffuseColor := LightVals.PLValigned.ColInt[UpperIndex - 1]
    else
    begin
      LowerIndex := UpperIndex - 1;
      UpperIndex := UpperIndex and 3;
      Weight := (ColorIndex - LightVals.IColPos[LowerIndex]) *
        LightVals.sICDiv[LowerIndex];
      DiffuseColor := LinInterpolate2SVecs(
        LightVals.PLValigned.ColInt[UpperIndex],
        LightVals.PLValigned.ColInt[LowerIndex], Weight);
    end;
    SpecularColor[0] := DiffuseColor[3];
    SpecularColor[1] := DiffuseColor[3];
    SpecularColor[2] := DiffuseColor[3];
    SpecularColor[3] := DiffuseColor[3];
    DiffuseColor[3] := 0;
    Exit;
  end;

  if (LightVals.iColOnOT and 1) = 0 then ColorIndex := Sample.SIgradient
  else ColorIndex := Sample.OTrap and $7FFF;
  ColorIndex := Round(MinMaxCS(-1e9, ((ColorIndex - LightVals.sCStart) *
    LightVals.sCmul + LightVals.sColZmul * ZPosition) * 16384, 1e9));
  UpperIndex := 5;
  if LightVals.bColCycling then ColorIndex := ColorIndex and 32767
  else
  begin
    if ColorIndex < 0 then
    begin
      SpecularColor := LightVals.PLValigned.ColSpe[0];
      DiffuseColor := LightVals.PLValigned.ColDif[0];
      Exit;
    end
    else if ColorIndex >= LightVals.ColPos[9] then
    begin
      SpecularColor := LightVals.PLValigned.ColSpe[9];
      DiffuseColor := LightVals.PLValigned.ColDif[9];
      Exit;
    end;
  end;
  if LightVals.ColPos[UpperIndex] < ColorIndex then
    repeat Inc(UpperIndex) until (UpperIndex = 10) or
      (LightVals.ColPos[UpperIndex] >= ColorIndex)
  else
    while (UpperIndex > 1) and
      (LightVals.ColPos[UpperIndex - 1] >= ColorIndex) do Dec(UpperIndex);
  if LightVals.bNoColIpol then
  begin
    SpecularColor := LightVals.PLValigned.ColSpe[UpperIndex - 1];
    DiffuseColor := LightVals.PLValigned.ColDif[UpperIndex - 1];
  end
  else
  begin
    LowerIndex := UpperIndex - 1;
    if UpperIndex > 9 then UpperIndex := 0;
    Weight := (ColorIndex - LightVals.ColPos[LowerIndex]) *
      LightVals.sCDiv[LowerIndex];
    SpecularColor := LinInterpolate2SVecs(
      LightVals.PLValigned.ColSpe[UpperIndex],
      LightVals.PLValigned.ColSpe[LowerIndex], Weight);
    DiffuseColor := LinInterpolate2SVecs(
      LightVals.PLValigned.ColDif[UpperIndex],
      LightVals.PLValigned.ColDif[LowerIndex], Weight);
  end;
end;

function ClampByte(Value: Single): Byte;
begin
  if Value <= 0 then Result := 0
  else if Value >= 255 then Result := 255
  else Result := Round(Value);
end;

function Clamp01(Value: Single): Single;
begin
  if Value <= 0 then Result := 0
  else if Value >= 1 then Result := 1
  else Result := Value;
end;

function ApplyGamma(Value, GammaAmount: Single; GammaMode: Integer): Byte;
var GammaValue: Single;
begin
  Value := Max(0, Min(255, Value));
  if GammaMode < 32 then GammaValue := Sqr(Value) / 255
  else if GammaMode > 32 then GammaValue := Sqrt(Value * 255)
  else GammaValue := Value;
  Result := ClampByte(Value + GammaAmount * (GammaValue - Value));
end;

function ColorComponent(Color: Cardinal; Component: Integer): Byte;
begin
  Result := (Color shr (Component * 8)) and $FF;
end;

function InterpolateCardinalColor(Color1, Color2: Cardinal;
  Weight2: Single): TFloatRGB;
var Component: Integer;
begin
  if Weight2 < 0 then Weight2 := 0;
  if Weight2 > 1 then Weight2 := 1;
  for Component := 0 to 2 do
    Result[Component] := ColorComponent(Color1, Component) * (1 - Weight2) +
      ColorComponent(Color2, Component) * Weight2;
end;

function InterpolateRGB(const Color1, Color2: TRGB;
  Weight2: Single): TFloatRGB;
var Component: Integer;
begin
  if Weight2 < 0 then Weight2 := 0;
  if Weight2 > 1 then Weight2 := 1;
  for Component := 0 to 2 do
    Result[Component] := Color1[Component] * (1 - Weight2) +
      Color2[Component] * Weight2;
end;

function DepthColor(const Header: TMandHeader10; Y: Integer): TFloatRGB;
var Position: Single;
    FunctionIndex: Integer;
begin
  if Header.Height > 0 then Position := Y / Header.Height
  else Position := 0.5;
  FunctionIndex := Header.Light.TBoptions shr 30;
  if FunctionIndex = 1 then Position := Sqr(Position)
  else if FunctionIndex <> 0 then Position := Sqrt(Position);
  { The original LinInterpolate2SVecs(DepthCol2, DepthCol, Position)
    evaluates to DepthCol at zero and DepthCol2 at one. }
  Result := InterpolateRGB(Header.Light.DepthCol2, Header.Light.DepthCol,
    1 - Position);
end;

function DecodeZPosition(var Header: TMandHeader10;
  const Sample: TsiLight5; ZCorrection, ZMultiplier,
  ZStartDifference: Double): Single;
var EncodedDepth: Cardinal;
    Distance: Double;
begin
  if Sample.Zpos >= 32768 then EncodedDepth := 0
  else EncodedDepth := (Cardinal(Sample.Zpos) shl 8) or
    (Sample.RoughZposFine shr 8);
  Distance := (Sqr((8388352 - EncodedDepth) / ZMultiplier + 1) - 1) *
    Header.dStepWidth / ZCorrection;
  Result := Distance + ZStartDifference;
end;

function ConvertVolumetricLight(Value: Integer): Integer;
begin
  Value := Value and $3FF;
  Result := (Value and $7F) shl (Value shr 7);
end;

function SurfaceColor(const Light: TLightingParas9; Position: Integer;
  NoInterpolation: Boolean): TFloatRGB;
var LowerIndex, UpperIndex, Span: Integer;
    Weight: Single;
begin
  if (Light.TBoptions and $4000) <> 0 then Position := Position and $7FFF
  else
  begin
    if Position < 0 then Position := 0;
    if Position > Light.LCols[9].Position then Position := Light.LCols[9].Position;
  end;
  UpperIndex := 1;
  while (UpperIndex < 10) and
    (Light.LCols[UpperIndex].Position < Position) do Inc(UpperIndex);
  LowerIndex := UpperIndex - 1;
  if NoInterpolation then
  begin
    Result := InterpolateCardinalColor(Light.LCols[LowerIndex].ColorDif,
      Light.LCols[LowerIndex].ColorDif, 0);
    Exit;
  end;
  if (UpperIndex > 9) or
    ((UpperIndex = 9) and (Position > Light.LCols[9].Position)) then
    UpperIndex := 0;
  if UpperIndex = 0 then Span := 32767 - Light.LCols[LowerIndex].Position
  else Span := Light.LCols[UpperIndex].Position - Light.LCols[LowerIndex].Position;
  if Span < 1 then Weight := 0
  else Weight := (Position - Light.LCols[LowerIndex].Position) / Span;
  Result := InterpolateCardinalColor(Light.LCols[LowerIndex].ColorDif,
    Light.LCols[UpperIndex].ColorDif, Weight);
end;

function InteriorColor(const Light: TLightingParas9; Position: Integer;
  NoInterpolation: Boolean): TFloatRGB;
var LowerIndex, UpperIndex, Span: Integer;
    Weight: Single;
begin
  if (Light.TBoptions and $4000) <> 0 then Position := Position and $7FFF
  else
  begin
    if Position < 0 then Position := 0;
    if Position > Light.ICols[3].Position then Position := Light.ICols[3].Position;
  end;
  UpperIndex := 1;
  while (UpperIndex < 4) and
    (Light.ICols[UpperIndex].Position < Position) do Inc(UpperIndex);
  LowerIndex := UpperIndex - 1;
  if NoInterpolation then
  begin
    Result := InterpolateCardinalColor(Light.ICols[LowerIndex].Color,
      Light.ICols[LowerIndex].Color, 0);
    Exit;
  end;
  if (UpperIndex > 3) or
    ((UpperIndex = 3) and (Position > Light.ICols[3].Position)) then
    UpperIndex := 0;
  if UpperIndex = 0 then Span := 32767 - Light.ICols[LowerIndex].Position
  else Span := Light.ICols[UpperIndex].Position - Light.ICols[LowerIndex].Position;
  if Span < 1 then Weight := 0
  else Weight := (Position - Light.ICols[LowerIndex].Position) / Span;
  Result := InterpolateCardinalColor(Light.ICols[LowerIndex].Color,
    Light.ICols[UpperIndex].Color, Weight);
end;

procedure ShadeMB3DFrame(var Header: TMandHeader10; const LightVals: TLightVals;
  const Samples: array of TsiLight5; CalculateHardShadows: Boolean;
  out Pixels: TByteBuffer;
  out DirectionalLights, SkippedLights, DepthFoggedPixels,
  DynamicFoggedPixels: Integer; out MeanDepthFog, MeanDynamicFog: Single);
var Lights: array[0..5] of TLightInfo;
    Sample: TsiLight5;
    Normal: TSVec;
    BaseColor, AmbientColor, BackgroundColor, FogColor, FogColor2: TFloatRGB;
    DiffuseColor, SpecularColor, ViewVec: TSVec;
    AmbientAmount, AmbientFactor, AmbientStrength, DiffuseAmount,
    DiffuseShadowing, DotRaw, DotValue, Lamp, Shadow, SpecularAmount,
    TopWeight, DepthAmount, FogAmount, FogAmount2, FogTotal,
    DepthFogTotal, Roughness, ZPosition: Single;
    Component, Index, LightIndex, PixelOffset: Integer;
    FogRayCount, X, Y: Integer;
    ZCorrection, ZMultiplier, ZStartDifference: Double;
    AngleX, AngleY: Double;
    IsInside: Boolean;
    NoHardShadow, SubtractAmbientShadow: Boolean;
    GammaAmount: Single;
    GammaMode: Integer;
begin
  EnsureCosTables;
  SetLength(Pixels, Length(Samples) * 3);
  DirectionalLights := 0;
  SkippedLights := 0;
  DepthFoggedPixels := 0;
  DynamicFoggedPixels := 0;
  MeanDepthFog := 0;
  MeanDynamicFog := 0;
  for LightIndex := 0 to 5 do
    if (Header.Light.Lights[LightIndex].Loption and 1) = 0 then
    begin
      if (Header.Light.Lights[LightIndex].Loption and 6) <> 0 then
      begin
        Inc(SkippedLights);
        Continue;
      end;
      AngleX := D7BtoDouble(Header.Light.Lights[LightIndex].LYpos);
      AngleY := -D7BtoDouble(Header.Light.Lights[LightIndex].LXpos);
      BuildViewVectorFOV(AngleX, AngleY,
        @Lights[DirectionalLights].Direction);
      SVectorChangeSign(@Lights[DirectionalLights].Direction);
      if (Header.Light.Lights[LightIndex].Loption and $20) <> 0 then
        RotateSVectorReverse(@Lights[DirectionalLights].Direction,
          @Header.hVGrads);
      Lamp := ShortFloatToSingle(@Header.Light.Lights[LightIndex].Lamp);
      Lights[DirectionalLights].ShadowMask := LightVals.iHSmask[LightIndex];
      Lights[DirectionalLights].HardShadowEnabled :=
        LightVals.iHSenabled[LightIndex] <> 0;
      Lights[DirectionalLights].HardShadowCalculated :=
        LightVals.iHScalced[LightIndex] <> 0;
      Lights[DirectionalLights].DiffuseFunction :=
        LightVals.iLightFuncDiff[LightIndex];
      Lights[DirectionalLights].SpecularPower :=
        LightVals.iLightPowFunc[LightIndex];
      for Component := 0 to 2 do
        Lights[DirectionalLights].Color[Component] :=
          Header.Light.Lights[LightIndex].Lcolor[Component] * Lamp;
      Inc(DirectionalLights);
    end;

  AmbientAmount := (Header.Light.TBpos[8] and $FFF) / 90;
  AmbientStrength := (Header.Light.TBpos[11] and $FF) / 53;
  DiffuseShadowing := Header.Light.Lights[3].AdditionalByteEx / 256;
  DiffuseAmount := Header.Light.TBpos[5] * 0.02;
  GammaMode := (Header.Light.TBoptions shr 23) and $3F;
  if GammaMode < 32 then GammaAmount := 1 - GammaMode / 32
  else if GammaMode > 32 then GammaAmount := (GammaMode - 32) / 31
  else GammaAmount := 0;
  CalcPPZvals(Header, ZCorrection, ZMultiplier, ZStartDifference);
  FogColor[0] := Header.Light.DynFogR;
  FogColor[1] := Header.Light.DynFogG;
  FogColor[2] := Header.Light.DynFogB;
  for Component := 0 to 2 do
    FogColor2[Component] := Header.Light.DynFogCol2[Component];
  for Index := 0 to High(Samples) do
  begin
    Sample := Samples[Index];
    PixelOffset := Index * 3;
    Y := Index div Header.Width;
    X := Index - Y * Header.Width;
    BaseColor := DepthColor(Header, Y);
    ZPosition := DecodeZPosition(Header, Sample, ZCorrection, ZMultiplier,
      ZStartDifference);
    if Sample.Zpos >= 32768 then
    begin
      BackgroundColor := BaseColor;
      DepthAmount := Max(0, 1 - 28000 * LightVals.sDepth);
    end
    else
    begin
      Normal := MakeSVecFromNormalsD(@Sample);
      if Sample.AmbShadow >= 16383 then Shadow := 1
      else Shadow := Sample.AmbShadow / 16383;
      if AmbientStrength > 1 then
        AmbientFactor := 1 - Shadow + (AmbientStrength - 1) *
          (Sqr(1 - Shadow) - (1 - Shadow))
      else AmbientFactor := 1 - AmbientStrength * Shadow;
      AmbientFactor := Max(0, Min(1, AmbientFactor));
      IsInside := Sample.SIgradient > 32767;
      CalcObjectColors(LightVals, Sample, ZPosition, IsInside, DiffuseColor,
        SpecularColor);
      for Component := 0 to 2 do
        BaseColor[Component] := DiffuseColor[Component] * 255;

      TopWeight := (Normal[1] + 1) * 0.5;
      AmbientColor := InterpolateRGB(Header.Light.AmbCol2,
        Header.Light.AmbCol, TopWeight);
      for Component := 0 to 2 do
        BackgroundColor[Component] := BaseColor[Component] *
          AmbientColor[Component] * AmbientAmount * AmbientFactor / 255;
      for LightIndex := 0 to DirectionalLights - 1 do
      begin
        DotRaw := Normal[0] * Lights[LightIndex].Direction[0] +
          Normal[1] * Lights[LightIndex].Direction[1] +
          Normal[2] * Lights[LightIndex].Direction[2];
        Roughness := (Sample.RoughZposFine and $FF) *
          LightVals.sRoughnessFactor;
        DotValue := HeadlessGetCosTabVal(Lights[LightIndex].DiffuseFunction,
          DotRaw, Roughness);
        if DotValue > 0 then
        begin
          NoHardShadow := (Lights[LightIndex].ShadowMask = -1) or
            ((Sample.Shadow and Lights[LightIndex].ShadowMask) = 0) or
            (not Lights[LightIndex].HardShadowCalculated);
          if NoHardShadow then
          begin
            SubtractAmbientShadow := Lights[LightIndex].HardShadowCalculated xor
              Lights[LightIndex].HardShadowEnabled;
            if SubtractAmbientShadow then
              DotValue := DotValue * AmbientFactor
            else
              DotValue := DotValue * (1 + DiffuseShadowing *
                (AmbientFactor - 1));
            if Lights[LightIndex].ShadowMask = -1 then
              DotValue := DotValue * (Sample.Shadow shr 10) * s1d63;
          end
          else
            DotValue := 0;
          if DotValue > 0 then
          begin
            for Component := 0 to 2 do
              BackgroundColor[Component] := BackgroundColor[Component] +
                BaseColor[Component] * Lights[LightIndex].Color[Component] *
                DotValue * DiffuseAmount / 255;
          end;
        end;
      end;
      CalcViewVecForPixel(ViewVec, Header, X, Y);
      for LightIndex := 0 to DirectionalLights - 1 do
      begin
        SpecularAmount := DotOf2VecNormalize(Normal,
          Lights[LightIndex].Direction, ViewVec);
        if SpecularAmount > 0 then
        begin
          NoHardShadow := (Lights[LightIndex].ShadowMask = -1) or
            ((Sample.Shadow and Lights[LightIndex].ShadowMask) = 0) or
            (not Lights[LightIndex].HardShadowCalculated);
          if NoHardShadow then
          begin
            Roughness := (Sample.RoughZposFine and $FF) *
              LightVals.sRoughnessFactor;
            SpecularAmount := (1 + MinCS(1, Roughness * 2) *
              (1 / Lights[LightIndex].SpecularPower - 1)) *
              LightVals.sSpec *
              FastIntPow(SpecularAmount, Lights[LightIndex].SpecularPower);
            SubtractAmbientShadow := Lights[LightIndex].HardShadowCalculated xor
              Lights[LightIndex].HardShadowEnabled;
            if SubtractAmbientShadow then
              SpecularAmount := SpecularAmount * AmbientFactor
            else
              SpecularAmount := SpecularAmount * (1 + DiffuseShadowing *
                (AmbientFactor - 1));
            if Lights[LightIndex].ShadowMask = -1 then
              SpecularAmount := SpecularAmount * (Sample.Shadow shr 10) *
                s1d63;
            for Component := 0 to 2 do
              BackgroundColor[Component] := BackgroundColor[Component] +
                SpecularColor[Component] *
                Lights[LightIndex].Color[Component] * SpecularAmount;
          end;
        end;
      end;
      DepthAmount := Max(0, (Integer(Sample.Zpos) - 28000) *
        LightVals.sDepth + 1);
    end;

    if LightVals.bFarFog and (DepthAmount < 1) then
      if LightVals.bCalcPixColSqr then
        DepthAmount := 1 - Sqr(Sqr(1 - DepthAmount))
      else DepthAmount := 1 - Sqr(1 - DepthAmount);
    DepthFogTotal := Abs(1 - DepthAmount);
    if DepthFogTotal > 1e-6 then Inc(DepthFoggedPixels);
    MeanDepthFog := MeanDepthFog + DepthFogTotal;
    for Component := 0 to 2 do
      BackgroundColor[Component] := BackgroundColor[Component] * DepthAmount +
        BaseColor[Component] * Max(0, 1 - DepthAmount);

    if LightVals.bVolLight then
      FogRayCount := ConvertVolumetricLight(Sample.Shadow)
    else FogRayCount := Sample.Shadow and $3FF;
    FogAmount := (FogRayCount - LightVals.sShad -
      LightVals.sShadZmul * ZPosition) * LightVals.sShadGr;
    if (LightVals.bDFogOptions and 2) <> 0 then FogAmount := Max(0, FogAmount);
    FogAmount2 := Min(1, FogRayCount * LightVals.sDynFogMul) * FogAmount;
    if (LightVals.bDFogOptions and 1) <> 0 then
    begin
      FogAmount := Clamp01(FogAmount);
      FogAmount2 := Clamp01(FogAmount2);
      for Component := 0 to 2 do
        BackgroundColor[Component] := BackgroundColor[Component] *
          (1 - FogAmount);
    end;
    for Component := 0 to 2 do
      BackgroundColor[Component] := BackgroundColor[Component] +
        FogColor[Component] * (FogAmount - FogAmount2) +
        FogColor2[Component] * FogAmount2;
    FogTotal := Max(Abs(FogAmount), Abs(FogAmount2));
    if FogTotal > 1e-6 then Inc(DynamicFoggedPixels);
    MeanDynamicFog := MeanDynamicFog + FogTotal;
    for Component := 0 to 2 do
      Pixels[PixelOffset + Component] := ApplyGamma(
        BackgroundColor[Component], GammaAmount, GammaMode);
  end;
  if Length(Samples) > 0 then
  begin
    MeanDepthFog := MeanDepthFog / Length(Samples);
    MeanDynamicFog := MeanDynamicFog / Length(Samples);
  end;
end;

end.
