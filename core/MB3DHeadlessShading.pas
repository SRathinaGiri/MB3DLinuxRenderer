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
    ShadowMask: Word;
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
  if Header.Height > 1 then Position := Y / (Header.Height - 1)
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
    AmbientAmount, AmbientFactor, AmbientStrength, DiffuseAmount,
    DiffuseShadowing, DotValue, Lamp, Shadow, TopWeight, DepthAmount,
    FogAmount, FogAmount2, FogTotal, DepthFogTotal, ZPosition: Single;
    ColorPosition, Component, Index, LightIndex, PixelOffset: Integer;
    FogRayCount, Y: Integer;
    OuterStart, OuterMultiplier, InnerStart, InnerMultiplier: Single;
    ZCorrection, ZMultiplier, ZStartDifference: Double;
    AngleX, AngleY: Double;
    IsInside, NoInterpolation: Boolean;
    GammaAmount: Single;
    GammaMode: Integer;
begin
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
      Lights[DirectionalLights].ShadowMask := $400 shl LightIndex;
      for Component := 0 to 2 do
        Lights[DirectionalLights].Color[Component] :=
          Header.Light.Lights[LightIndex].Lcolor[Component] * Lamp;
      Inc(DirectionalLights);
    end;

  AmbientAmount := (Header.Light.TBpos[8] and $FFF) / 90;
  AmbientStrength := (Header.Light.TBpos[11] and $FF) / 53;
  DiffuseShadowing := Header.Light.Lights[3].AdditionalByteEx / 256;
  DiffuseAmount := Header.Light.TBpos[5] * 0.02;
  NoInterpolation := (Header.Light.Lights[3].FreeByte and 1) <> 0;
  GammaMode := (Header.Light.TBoptions shr 23) and $3F;
  if GammaMode < 32 then GammaAmount := 1 - GammaMode / 32
  else if GammaMode > 32 then GammaAmount := (GammaMode - 32) / 31
  else GammaAmount := 0;
  CalcSCstartAndSCmul(@Header, OuterStart, OuterMultiplier, False);
  CalcSCstartAndSCmul(@Header, InnerStart, InnerMultiplier, True);
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
    BaseColor := DepthColor(Header, Y);
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
      if IsInside then
      begin
        ColorPosition := Round((Sample.SIgradient - InnerStart) *
          InnerMultiplier * 16384);
        BaseColor := InteriorColor(Header.Light, ColorPosition, NoInterpolation);
      end;
      if not IsInside then
      begin
        ColorPosition := Round((Sample.SIgradient - OuterStart) *
          OuterMultiplier * 16384);
        if (Header.Light.Lights[1].FreeByte and 1) <> 0 then
          ColorPosition := Round(((Sample.OTrap and $7FFF) - OuterStart) *
            OuterMultiplier * 16384);
        BaseColor := SurfaceColor(Header.Light, ColorPosition, NoInterpolation);
      end;

      TopWeight := (Normal[1] + 1) * 0.5;
      AmbientColor := InterpolateRGB(Header.Light.AmbCol2,
        Header.Light.AmbCol, TopWeight);
      for Component := 0 to 2 do
        BackgroundColor[Component] := BaseColor[Component] *
          AmbientColor[Component] * AmbientAmount * AmbientFactor / 255;
      for LightIndex := 0 to DirectionalLights - 1 do
      begin
        DotValue := Normal[0] * Lights[LightIndex].Direction[0] +
          Normal[1] * Lights[LightIndex].Direction[1] +
          Normal[2] * Lights[LightIndex].Direction[2];
        if DotValue > 0 then
        begin
          if CalculateHardShadows and ((Header.bCalculateHardShadow and
            (Lights[LightIndex].ShadowMask shr 8)) <> 0) and
            ((Sample.Shadow and Lights[LightIndex].ShadowMask) = 0) then
            DotValue := 0;
          DotValue := DotValue * (1 + DiffuseShadowing *
            (AmbientFactor - 1));
          for Component := 0 to 2 do
            BackgroundColor[Component] := BackgroundColor[Component] +
              BaseColor[Component] * Lights[LightIndex].Color[Component] *
              DotValue * DiffuseAmount / 255;
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
    ZPosition := DecodeZPosition(Header, Sample, ZCorrection, ZMultiplier,
      ZStartDifference);
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
