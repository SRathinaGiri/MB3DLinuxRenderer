unit MB3DHeadlessShading;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses TypeDefinitions, MB3DPortablePNG;

procedure ShadeMB3DFrame(var Header: TMandHeader10;
  const Samples: array of TsiLight5; CalculateHardShadows: Boolean;
  out Pixels: TByteBuffer;
  out DirectionalLights, SkippedLights: Integer);

implementation

uses Math, Math3D, HeaderTrafos;

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

procedure ShadeMB3DFrame(var Header: TMandHeader10;
  const Samples: array of TsiLight5; CalculateHardShadows: Boolean;
  out Pixels: TByteBuffer;
  out DirectionalLights, SkippedLights: Integer);
var Lights: array[0..5] of TLightInfo;
    Sample: TsiLight5;
    Normal: TSVec;
    BaseColor, AmbientColor, BackgroundColor: TFloatRGB;
    AmbientAmount, AmbientFactor, AmbientStrength, DiffuseAmount,
    DiffuseShadowing, DotValue, Lamp, Shadow, TopWeight: Single;
    ColorPosition, Component, Index, LightIndex, PixelOffset: Integer;
    OuterStart, OuterMultiplier, InnerStart, InnerMultiplier: Single;
    AngleX, AngleY: Double;
    IsInside, NoInterpolation: Boolean;
    GammaAmount: Single;
    GammaMode: Integer;
begin
  SetLength(Pixels, Length(Samples) * 3);
  DirectionalLights := 0;
  SkippedLights := 0;
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
  for Index := 0 to High(Samples) do
  begin
    Sample := Samples[Index];
    PixelOffset := Index * 3;
    if Sample.Zpos >= 32768 then
    begin
      if Header.Height > 1 then TopWeight := 1 - (Index div Header.Width) /
        (Header.Height - 1) else TopWeight := 0.5;
      BackgroundColor := InterpolateRGB(Header.Light.DepthCol2,
        Header.Light.DepthCol, TopWeight);
      for Component := 0 to 2 do
        Pixels[PixelOffset + Component] := ApplyGamma(
          BackgroundColor[Component], GammaAmount, GammaMode);
      Continue;
    end;

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
    end
    else
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
    for Component := 0 to 2 do
      Pixels[PixelOffset + Component] := ApplyGamma(
        BackgroundColor[Component], GammaAmount, GammaMode);
  end;
end;

end.
