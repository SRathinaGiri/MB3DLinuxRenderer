unit MB3DHeadlessReflection;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}


interface

uses TypeDefinitions, MB3DPortablePNG;

type
  THeadlessReflectionMode = (hrmReport, hrmOff, hrmPost);

  THeadlessReflectionStatus = record
    SavedEnabled: Boolean;
    Active: Boolean;
    TransmissionEnabled: Boolean;
    TransmissionOnlyDIFS: Boolean;
    TransmissionIndex: Single;
    TransmissionAbsorption: Single;
    TransmissionScattering: Single;
    Amount: Single;
    ReflectionCount: Integer;
    DiffuseReflects: Integer;
    InsideOptions: Integer;
  end;

procedure DescribeHeadlessReflection(const Header: TMandHeader10;
  out Status: THeadlessReflectionStatus);

function ApplyHeadlessReflection(var Header: TMandHeader10;
  var LightVals: TLightVals; const Samples: array of TsiLight5;
  var Pixels: TByteBuffer; ThreadCount: Integer; Mode: THeadlessReflectionMode;
  out Status: THeadlessReflectionStatus; out AppliedMode: string;
  out ReflectedPixels: Integer; out ErrorText: string): Boolean;

implementation

uses SysUtils, Math, Types, Calc, HeaderTrafos, Math3D;

type
  TFloatRGB = array[0..2] of Single;
  TReflectionLightInfo = record
    Direction: TSVec;
    Color: TFloatRGB;
    ShadowMask: Integer;
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
    DiffCosTabNsmall[2][I] := D * 0.5 + 0.5;
    DiffCosTabNsmall[3][I] := Sqr(D * 0.5 + 0.5);
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

function SampleEncodedDepth(const Sample: TsiLight5): Integer;
begin
  Result := Integer((Cardinal(Sample.RoughZposFine) or
    (Cardinal(Sample.Zpos) shl 16)) shr 8);
end;

function ClampByte(Value: Single): Byte;
begin
  if Value <= 0 then Result := 0
  else if Value >= 255 then Result := 255
  else Result := Round(Value);
end;

function ReflectionWeight(const LightVals: TLightVals; const Sample: TsiLight5;
  const Status: THeadlessReflectionStatus): Single;
var
  ColorIndex, UpperIndex, LowerIndex: Integer;
  Weight, Spec: Single;
  SpecColor: TSVec;
begin
  Result := 0;
  if (Sample.Zpos >= 32768) or (Status.Amount <= 0) then Exit;
  if Sample.SIgradient > 32767 then
  begin
    ColorIndex := Round(((Sample.SIgradient - LightVals.sCiStart) *
      LightVals.sCimul) * 16384);
    if LightVals.bColCycling then ColorIndex := ColorIndex and 32767
    else if ColorIndex < 0 then
    begin
      Spec := LightVals.PLValigned.ColInt[0][3];
      Result := Min(0.95, Max(0, Spec * Status.Amount));
      Exit;
    end
    else if ColorIndex > LightVals.IColPos[3] then
    begin
      Spec := LightVals.PLValigned.ColInt[3][3];
      Result := Min(0.95, Max(0, Spec * Status.Amount));
      Exit;
    end;
    UpperIndex := 1;
    while (UpperIndex < 4) and
      (LightVals.IColPos[UpperIndex] < ColorIndex) do Inc(UpperIndex);
    if LightVals.bNoColIpol then
      Spec := LightVals.PLValigned.ColInt[UpperIndex - 1][3]
    else
    begin
      LowerIndex := UpperIndex - 1;
      UpperIndex := UpperIndex and 3;
      Weight := (ColorIndex - LightVals.IColPos[LowerIndex]) *
        LightVals.sICDiv[LowerIndex];
      Spec := LightVals.PLValigned.ColInt[UpperIndex][3] * Weight +
        LightVals.PLValigned.ColInt[LowerIndex][3] * (1 - Weight);
    end;
    Result := Min(0.95, Max(0, Spec * Status.Amount));
    Exit;
  end;

  if (LightVals.iColOnOT and 1) = 0 then ColorIndex := Sample.SIgradient
  else ColorIndex := Sample.OTrap and $7FFF;
  ColorIndex := Round(MinMaxCS(-1e9, ((ColorIndex - LightVals.sCStart) *
    LightVals.sCmul) * 16384, 1e9));
  UpperIndex := 5;
  if LightVals.bColCycling then ColorIndex := ColorIndex and 32767
  else if ColorIndex < 0 then
    SpecColor := LightVals.PLValigned.ColSpe[0]
  else if ColorIndex >= LightVals.ColPos[9] then
    SpecColor := LightVals.PLValigned.ColSpe[9]
  else
  begin
    if LightVals.ColPos[UpperIndex] < ColorIndex then
      repeat Inc(UpperIndex) until (UpperIndex = 10) or
        (LightVals.ColPos[UpperIndex] >= ColorIndex)
    else
      while (UpperIndex > 1) and
        (LightVals.ColPos[UpperIndex - 1] >= ColorIndex) do Dec(UpperIndex);
    if LightVals.bNoColIpol then
      SpecColor := LightVals.PLValigned.ColSpe[UpperIndex - 1]
    else
    begin
      LowerIndex := UpperIndex - 1;
      if UpperIndex > 9 then UpperIndex := 0;
      Weight := (ColorIndex - LightVals.ColPos[LowerIndex]) *
        LightVals.sCDiv[LowerIndex];
      SpecColor := LinInterpolate2SVecs(
        LightVals.PLValigned.ColSpe[UpperIndex],
        LightVals.PLValigned.ColSpe[LowerIndex], Weight);
    end;
  end;
  Spec := Max0S(YofSVec(@SpecColor));
  Result := Min(0.95, Max(0, Spec * Status.Amount));
end;

procedure CalcObjectColors(const LightVals: TLightVals; const Sample: TsiLight5;
  ZPosition: Single; out DiffuseColor, SpecularColor: TSVec);
var
  ColorIndex, LowerIndex, UpperIndex: Integer;
  Weight: Single;
begin
  if Sample.SIgradient > 32767 then
  begin
    ColorIndex := Round(((Sample.SIgradient - LightVals.sCiStart) *
      LightVals.sCimul + LightVals.sColZmul * ZPosition) * 16384);
    if LightVals.bColCycling then ColorIndex := ColorIndex and 32767
    else if ColorIndex < 0 then
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
  else if ColorIndex < 0 then
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

function Clamp01(Value: Single): Single;
begin
  if Value <= 0 then Result := 0
  else if Value >= 1 then Result := 1
  else Result := Value;
end;

procedure ShadeReflectedHit(const Header: TMandHeader10; const LightVals: TLightVals;
  const Sample: TsiLight5; const ViewVec: TSVec; ZPosition: Single;
  out Color: array of Single);
var
  Lights: array[0..5] of TReflectionLightInfo;
  Normal: TSVec;
  BaseColor, AmbientColor: TFloatRGB;
  DiffuseColor, SpecularColor: TSVec;
  AmbientAmount, AmbientFactor, AmbientStrength, DiffuseAmount,
  DiffuseShadowing, DotRaw, DotValue, Lamp, Shadow, SpecularAmount,
  TopWeight, DepthAmount, FogAmount, FogAmount2, Roughness: Single;
  Component, LightIndex, DirectionalLights: Integer;
  FogRayCount: Integer;
  AngleX, AngleY: Double;
  NoHardShadow, SubtractAmbientShadow: Boolean;
begin
  EnsureCosTables;
  DirectionalLights := 0;
  for LightIndex := 0 to 5 do
    if (Header.Light.Lights[LightIndex].Loption and 1) = 0 then
    begin
      if (Header.Light.Lights[LightIndex].Loption and 6) <> 0 then Continue;
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

  Normal := MakeSVecFromNormalsD(@Sample);
  if Sample.AmbShadow >= 16383 then Shadow := 1
  else Shadow := Sample.AmbShadow / 16383;
  AmbientStrength := (Header.Light.TBpos[11] and $FF) / 53;
  if AmbientStrength > 1 then
    AmbientFactor := 1 - Shadow + (AmbientStrength - 1) *
      (Sqr(1 - Shadow) - (1 - Shadow))
  else AmbientFactor := 1 - AmbientStrength * Shadow;
  AmbientFactor := Max(0, Min(1, AmbientFactor));
  AmbientAmount := (Header.Light.TBpos[8] and $FFF) / 90;
  DiffuseShadowing := Header.Light.Lights[3].AdditionalByteEx / 256;
  DiffuseAmount := Header.Light.TBpos[5] * 0.02;
  CalcObjectColors(LightVals, Sample, ZPosition, DiffuseColor, SpecularColor);
  for Component := 0 to 2 do BaseColor[Component] := DiffuseColor[Component] * 255;

  TopWeight := (Normal[1] + 1) * 0.5;
  for Component := 0 to 2 do
    AmbientColor[Component] := Header.Light.AmbCol2[Component] * (1 - TopWeight) +
      Header.Light.AmbCol[Component] * TopWeight;
  for Component := 0 to 2 do
    Color[Component] := BaseColor[Component] * AmbientColor[Component] *
      AmbientAmount * AmbientFactor / 255;

  for LightIndex := 0 to DirectionalLights - 1 do
  begin
    DotRaw := Normal[0] * Lights[LightIndex].Direction[0] +
      Normal[1] * Lights[LightIndex].Direction[1] +
      Normal[2] * Lights[LightIndex].Direction[2];
    Roughness := (Sample.RoughZposFine and $FF) * LightVals.sRoughnessFactor;
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
          (LightVals.iHSenabled[LightIndex] <> 0);
        if SubtractAmbientShadow then DotValue := DotValue * AmbientFactor
        else DotValue := DotValue * (1 + DiffuseShadowing *
          (AmbientFactor - 1));
        if Lights[LightIndex].ShadowMask = -1 then
          DotValue := DotValue * (Sample.Shadow shr 10) * s1d63;
        for Component := 0 to 2 do
          Color[Component] := Color[Component] +
            BaseColor[Component] * Lights[LightIndex].Color[Component] *
            DotValue * DiffuseAmount / 255;
      end;
    end;

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
          (LightVals.iHSenabled[LightIndex] <> 0);
        if SubtractAmbientShadow then SpecularAmount := SpecularAmount * AmbientFactor
        else SpecularAmount := SpecularAmount * (1 + DiffuseShadowing *
          (AmbientFactor - 1));
        if Lights[LightIndex].ShadowMask = -1 then
          SpecularAmount := SpecularAmount * (Sample.Shadow shr 10) * s1d63;
        for Component := 0 to 2 do
          Color[Component] := Color[Component] +
            SpecularColor[Component] *
            Lights[LightIndex].Color[Component] * SpecularAmount;
      end;
    end;
  end;

  DepthAmount := Max(0, (Integer(Sample.Zpos) - 28000) * LightVals.sDepth + 1);
  if LightVals.bFarFog and (DepthAmount < 1) then
    if LightVals.bCalcPixColSqr then
      DepthAmount := 1 - Sqr(Sqr(1 - DepthAmount))
    else DepthAmount := 1 - Sqr(1 - DepthAmount);
  for Component := 0 to 2 do
    Color[Component] := Color[Component] * DepthAmount +
      LightVals.PLValigned.sDepthCol[Component] * 255 * Max(0, 1 - DepthAmount);

  if LightVals.bVolLight then FogRayCount := (Sample.Shadow and $7F) shl
    ((Sample.Shadow and $3FF) shr 7)
  else FogRayCount := Sample.Shadow and $3FF;
  FogAmount := (FogRayCount - LightVals.sShad -
    LightVals.sShadZmul * ZPosition) * LightVals.sShadGr;
  if (LightVals.bDFogOptions and 2) <> 0 then FogAmount := Max(0, FogAmount);
  FogAmount2 := Min(1, FogRayCount * LightVals.sDynFogMul) * FogAmount;
  if (LightVals.bDFogOptions and 1) <> 0 then
  begin
    FogAmount := Clamp01(FogAmount);
    FogAmount2 := Clamp01(FogAmount2);
    for Component := 0 to 2 do Color[Component] := Color[Component] * (1 - FogAmount);
  end;
  for Component := 0 to 2 do
    Color[Component] := Color[Component] +
      LightVals.PLValigned.sDynFogCol[Component] * 255 * (FogAmount - FogAmount2) +
      LightVals.PLValigned.sDynFogCol2[Component] * 255 * FogAmount2;
end;

procedure BackgroundColorForRay(const Header: TMandHeader10; const LightVals: TLightVals;
  const Ray: TSVec; out Color: array of Single);
var
  YPos, Position: Single;
  Component, FuncIndex: Integer;
begin
  YPos := ArcSinSafe(Ray[1]) * Pi1d + 0.5;
  if YPos < 0 then YPos := 0 else if YPos > 1 then YPos := 1;
  Position := YPos;
  FuncIndex := Header.Light.TBoptions shr 30;
  if FuncIndex = 1 then Position := Sqr(Position)
  else if FuncIndex <> 0 then Position := Sqrt(Position);
  for Component := 0 to 2 do
    Color[Component] := (LightVals.PLValigned.sDepthCol[Component] *
      (1 - Position) + LightVals.PLValigned.sDepthCol2[Component] *
      Position) * 255;
end;

function TraceReflectedColor(var MCT: TMCTparameter; var It3D: TIteration3Dext;
  const StartPos: TPos3D; const IncomingVec, Normal: TVec3D;
  const Header: TMandHeader10;
  const LightVals: TLightVals; MaxSteps: Integer; out Color: array of Single): Boolean;
var
  Ray: TVec3D;
  RayS: TSVec;
  Step, Total, DE, LastStep, RSF: Double;
  Rough: Single;
  Temp: TsiLight5;
  Hit: Boolean;
  Index: Integer;
begin
  Result := False;
  Hit := False;
  Ray := SubtractVectors(@IncomingVec, ScaleVector(Normal,
    2 * DotOfVectors(@Normal, @IncomingVec) /
    Max(1e-30, SqrLengthOfVec(Normal))));
  if SqrLengthOfVec(Ray) < 1e-30 then Exit;
  MCT.pIt3Dext := @It3D;
  mCopyVec(@It3D.C1, @StartPos);
  Step := Max(0.01, MCT.DEstop * 0.25);
  mAddVecWeight(@It3D.C1, @Ray, Step);
  Total := Step;
  LastStep := Step;
  RSF := 1;
  for Index := 0 to MaxSteps - 1 do
  begin
    MCT.mZZ := Total;
    MCT.msDEstop := MCT.DEstop * (1 + Abs(Total) * MCT.mctDEstopFactor);
    DE := MCT.CalcDE(@It3D, @MCT);
    if (DE < MCT.msDEstop) and (It3D.ItResultI >= MCT.iMinIt) then
    begin
      Hit := True;
      Break;
    end;
    Step := Max(0.01, (DE - MCT.msDEsub * MCT.msDEstop) *
      MCT.sZstepDiv * RSF);
    if Step > Max(0.4, MCT.DEstop * 8) then
      Step := Max(0.4, MCT.DEstop * 8);
    Total := Total + Step;
    if Total > MCT.Zend then Break;
    mAddVecWeight(@It3D.C1, @Ray, Step);
    LastStep := Step;
  end;

  if not Hit then
  begin
    RayS := NormaliseSVector(DVecToSVec(Ray));
    BackgroundColorForRay(Header, LightVals, RayS, Color);
    Result := True;
    Exit;
  end;

  if LastStep > 0 then
    RMdoBinSearch(@MCT, DE, LastStep);
  FillChar(Temp, SizeOf(Temp), 0);
  MCT.mPsiLight := @Temp;
  Rough := 1;
  TCalculateNormalsFunc(MCT.pCalcNormals)(@MCT, Rough);
  RMdoColor(@MCT);
  CalcZposAndRough(@Temp, @MCT, Total);
  RayS := NormaliseSVector(DVecToSVec(Ray));
  ShadeReflectedHit(Header, LightVals, Temp, RayS,
    Total * Header.dStepWidth + MCT.sZZstmitDif, Color);
  Result := True;
end;

function ApplyPostReflection(var Header: TMandHeader10;
  var LightVals: TLightVals; const Samples: array of TsiLight5;
  var Pixels: TByteBuffer; ThreadCount: Integer;
  const Status: THeadlessReflectionStatus; out ReflectedPixels: Integer;
  out ErrorText: string): Boolean;
var
  Stats: TCalcThreadStats;
  StopRequested, InsideRendering: LongBool;
  MCT: TMCTparameter;
  It3D: TIteration3Dext;
  Rect: TRect;
  X, Y, Index, Offset, Component: Integer;
  ZZ, DE, BackStep, MixAmount: Double;
  Normal, Incoming: TVec3D;
  StartPos: TPos3D;
  RefColor: array[0..2] of Single;
begin
  Result := False;
  ErrorText := '';
  ReflectedPixels := 0;
  if (Length(Samples) <> Header.Width * Header.Height) or
    (Length(Pixels) <> Header.Width * Header.Height * 3) then
  begin
    ErrorText := 'Invalid reflection buffer dimensions';
    Exit;
  end;
  FillChar(Stats, SizeOf(Stats), 0);
  StopRequested := False;
  Stats.pLBcalcStop := @StopRequested;
  Rect := Types.Rect(0, 0, Header.Width - 1, Header.Height - 1);
  MCT := GetMCTparasFromHeader(Header, True);
  if not MCT.bMCTisValid then
  begin
    ErrorText := 'MB3D rejected the reflection render parameters';
    Exit;
  end;
  MCT.pSiLight := @Samples[0];
  MCT.SLoffset := Header.Width * SizeOf(TsiLight5);
  MCT.PLVals := @LightVals;
  MCT.PCalcThreadStats := @Stats;
  MCT.CalcRect := Rect;
  MCT.iThreadId := 1;
  MCT.iThreadCount := Max(1, ThreadCount);
  MCT.pIt3Dext := @It3D;
  CalcHSVecsFromLights(@LightVals, @MCT);
  IniIt3D(@MCT, @It3D);
  InsideRendering := MCT.bInsideRendering;

  for Y := 0 to Header.Height - 1 do
  begin
    MCT.CAFY := (Y / MCT.iMandHeight - 0.5) * MCT.FOVy;
    for X := 0 to Header.Width - 1 do
    begin
      Index := Y * Header.Width + X;
      if Samples[Index].Zpos >= 32768 then Continue;
      MixAmount := ReflectionWeight(LightVals, Samples[Index], Status);
      if MixAmount <= 0.001 then Continue;
      MCT.bInsideRendering := InsideRendering;
      MCT.bCalcInside := InsideRendering;
      if MCT.bInAndOutside and ((Samples[Index].OTrap and $8000) <> 0) then
      begin
        MCT.bInsideRendering := False;
        MCT.bCalcInside := False;
      end;
      RMCalculateVgradsFOV(@MCT, X + 1);
      RMCalculateStartPos(@MCT, X, Y);
      ZZ := (Sqr((8388351.5 - SampleEncodedDepth(Samples[Index])) /
        MCT.ZcMul + 1) - 1) / MCT.Zcorr;
      MCT.mZZ := ZZ;
      mAddVecWeight(@It3D.C1, @MCT.mVgradsFOV, MCT.mZZ);
      MCT.msDEstop := MCT.DEstop * (1 + MCT.mZZ * MCT.mctDEstopFactor);
      DE := MCT.CalcDE(@It3D, @MCT);
      BackStep := (Sqr((8388351.9 - SampleEncodedDepth(Samples[Index])) /
        MCT.ZcMul + 1) - 1) / MCT.Zcorr - MCT.mZZ;
      RMdoBinSearch(@MCT, DE, BackStep);
      Normal := MakeDVecFromNormals(@Samples[Index]);
      mCopyVec(@StartPos, @It3D.C1);
      Incoming := MCT.mVgradsFOV;
      if not TraceReflectedColor(MCT, It3D, StartPos, Incoming, Normal,
        Header, LightVals, 512, RefColor) then Continue;
      Offset := Index * 3;
      for Component := 0 to 2 do
        Pixels[Offset + Component] := ClampByte(Pixels[Offset + Component] *
          (1 - MixAmount) + RefColor[Component] * MixAmount);
      Inc(ReflectedPixels);
      IniIt3D(@MCT, @It3D);
    end;
  end;
  Result := True;
end;

procedure DescribeHeadlessReflection(const Header: TMandHeader10;
  out Status: THeadlessReflectionStatus);
var
  HeaderAddon: PTHeaderCustomAddon;
begin
  FillChar(Status, SizeOf(Status), 0);
  Status.SavedEnabled := (Header.bCalcSRautomatic and 1) <> 0;
  Status.TransmissionEnabled := (Header.bCalcSRautomatic and 2) <> 0;
  Status.TransmissionOnlyDIFS := (Header.bCalcSRautomatic and 4) <> 0;
  Status.Amount := Header.SRamount;
  Status.ReflectionCount := Header.SRreflectioncount;
  Status.TransmissionIndex := Header.sTRIndex;
  Status.TransmissionAbsorption := Header.sTransmissionAbsorption;
  Status.TransmissionScattering := Header.sTRscattering;
  Status.DiffuseReflects := Header.MCdiffReflects;
  Status.InsideOptions := 0;
  if Header.PCFAddon <> nil then
  begin
    HeaderAddon := PTHeaderCustomAddon(Header.PCFAddon);
    Status.InsideOptions := HeaderAddon.bOptions2;
    if (HeaderAddon.bOptions2 and 6) = 4 then
      Status.TransmissionIndex := 1;
  end;
  Status.Active := Status.SavedEnabled and (Status.Amount > 0) and
    (Status.ReflectionCount > 0);
end;

function ApplyHeadlessReflection(var Header: TMandHeader10;
  var LightVals: TLightVals; const Samples: array of TsiLight5;
  var Pixels: TByteBuffer; ThreadCount: Integer; Mode: THeadlessReflectionMode;
  out Status: THeadlessReflectionStatus; out AppliedMode: string;
  out ReflectedPixels: Integer; out ErrorText: string): Boolean;
begin
  Result := True;
  ErrorText := '';
  ReflectedPixels := 0;
  DescribeHeadlessReflection(Header, Status);
  if Mode = hrmOff then
  begin
    AppliedMode := 'disabled-by-cli';
    Exit;
  end;
  if not Status.Active then
  begin
    if Status.SavedEnabled then
      AppliedMode := 'saved-inactive'
    else
      AppliedMode := 'disabled';
    Exit;
  end;
  if Mode = hrmReport then
  begin
    AppliedMode := 'pending-recursive-post-pass';
    Exit;
  end;

  if Status.TransmissionEnabled then
    AppliedMode := 'post-reflection-transmission-pending'
  else
    AppliedMode := 'post-reflection';
  Result := ApplyPostReflection(Header, LightVals, Samples, Pixels,
    ThreadCount, Status, ReflectedPixels, ErrorText);
end;

end.
