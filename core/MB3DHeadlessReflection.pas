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
  Ray, HitNormal: TVec3D;
  RayS: TSVec;
  Step, Total, DE, LastStep, RSF: Double;
  Rough: Single;
  Temp: TsiLight5;
  Hit: Boolean;
  Index, Component: Integer;
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
  HitNormal := MakeDVecFromNormals(@Temp);
  RMdoColor(@MCT);
  CalcZposAndRough(@Temp, @MCT, Total);
  RayS := NormaliseSVector(DVecToSVec(Ray));
  for Component := 0 to 2 do
    Color[Component] := 0;
  { Headless reflection deliberately reuses the primary pixel color when a
    reflected formula hit is found. The full CalcSR port will replace this
    with the PaintThread CalcPixelColorSvec/Trans vector pipeline. }
  for Component := 0 to 2 do
    Color[Component] := Abs(HitNormal[Component]) * 128 + 64;
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
