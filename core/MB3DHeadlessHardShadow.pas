unit MB3DHeadlessHardShadow;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses TypeDefinitions;

function ApplyHeadlessPostHardShadows(var Header: TMandHeader10;
  var LightVals: TLightVals; var Samples: array of TsiLight5;
  ThreadCount: Integer; out ShadowedPixels, ShadowLights: Integer;
  out ErrorText: string): Boolean;

implementation

uses Math, Types, Calc, HeaderTrafos, Math3D;

function SampleEncodedDepth(const Sample: TsiLight5): Integer;
begin
  Result := Integer((Cardinal(Sample.RoughZposFine) or
    (Cardinal(Sample.Zpos) shl 16)) shr 8);
end;

function ApplyHeadlessPostHardShadows(var Header: TMandHeader10;
  var LightVals: TLightVals; var Samples: array of TsiLight5;
  ThreadCount: Integer; out ShadowedPixels, ShadowLights: Integer;
  out ErrorText: string): Boolean;
var
  Stats: TCalcThreadStats;
  StopRequested, InsideRendering, DELimited: LongBool;
  MCT: TMCTparameter;
  It3D: TIteration3Dext;
  Rect: TRect;
  X, Y, LightIndex, Index, BitIndex, PreviousHScalculated: Integer;
  DE, BackStep, ZZ: Double;
begin
  Result := False;
  ErrorText := '';
  ShadowedPixels := 0;
  ShadowLights := 0;
  if (Header.Width < 1) or (Header.Height < 1) or
    (Length(Samples) <> Header.Width * Header.Height) then
  begin
    ErrorText := 'Invalid hard-shadow buffer dimensions';
    Exit;
  end;

  PreviousHScalculated := Header.bHScalculated;
  if (Header.bCalc1HSsoft and 1) <> 0 then
    Header.bHScalculated := (PreviousHScalculated and 1) or
      Header.bCalculateHardShadow
  else
    Header.bHScalculated := (PreviousHScalculated and $FD) or
      Header.bCalculateHardShadow;
  MakeLightValsFromHeaderLight(@Header, @LightVals, 1, Header.bStereoMode);
  for LightIndex := 0 to 5 do
    if (Header.bCalculateHardShadow and (4 shl LightIndex)) <> 0 then
      Inc(ShadowLights);

  if ShadowLights = 0 then
  begin
    Result := True;
    Exit;
  end;

  FillChar(Stats, SizeOf(Stats), 0);
  StopRequested := False;
  Stats.pLBcalcStop := @StopRequested;
  Rect := Types.Rect(0, 0, Header.Width - 1, Header.Height - 1);
  MCT := GetMCTparasFromHeader(Header, True);
  if not MCT.bMCTisValid then
  begin
    ErrorText := 'MB3D rejected the hard-shadow render parameters';
    Header.bHScalculated := PreviousHScalculated;
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
  MCT.iDEAddSteps := 8;
  It3D.CalcSIT := False;
  InsideRendering := MCT.bInsideRendering;

  for Y := 0 to Header.Height - 1 do
  begin
    MCT.CAFY := (Y / MCT.iMandHeight - 0.5) * MCT.FOVy;
    for X := 0 to Header.Width - 1 do
    begin
      Index := Y * Header.Width + X;
      Samples[Index].Shadow := Samples[Index].Shadow and
        (((MCT.calcHardShadow and $FC) shl 8) xor $FFFF);
      if (Samples[Index].Zpos >= 32768) or
        (Samples[Index].SIgradient >= 32768) then Continue;

      MCT.bInsideRendering := InsideRendering;
      MCT.bCalcInside := InsideRendering;
      RMCalculateVgradsFOV(@MCT, X + 1);
      RMCalculateStartPos(@MCT, X, Y);
      ZZ := (Sqr((8388351.5 - SampleEncodedDepth(Samples[Index])) /
        MCT.ZcMul + 1) - 1) / MCT.Zcorr;
      MCT.mZZ := ZZ;
      mAddVecWeight(@It3D.C1, @MCT.mVgradsFOV, MCT.mZZ);
      MCT.msDEstop := MCT.DEstop * (1 + MCT.mZZ * MCT.mctDEstopFactor);
      DE := MCT.CalcDE(@It3D, @MCT);

      if MCT.bInAndOutside and ((Samples[Index].OTrap and $8000) <> 0) then
      begin
        MCT.bInsideRendering := False;
        MCT.bCalcInside := False;
        DE := MCT.CalcDE(@It3D, @MCT);
      end;

      DELimited := (It3D.ItResultI < MCT.MaxItsResult) or
        (DE < MCT.msDEstop);
      if DELimited then
      begin
        BackStep := (Sqr((8388351.9 - SampleEncodedDepth(Samples[Index])) /
          MCT.ZcMul + 1) - 1) / MCT.Zcorr - MCT.mZZ;
        RMdoBinSearch(@MCT, DE, BackStep);
      end
      else
        RMdoBinSearchIt(@MCT, MCT.mZZ);

      MCT.mZZ := Max(0, MCT.mZZ - 0.1);
      mAddVecWeight(@It3D.C1, @MCT.mVgradsFOV, -0.1);
      MCT.msDEstop := MCT.DEstop * (1 + MCT.mZZ * MCT.mctDEstopFactor);
      CalcHS(@MCT, @Samples[Index], Y);
    end;
  end;

  for Index := 0 to High(Samples) do
    if Samples[Index].Zpos < 32768 then
      for BitIndex := 0 to 5 do
        if ((Header.bCalculateHardShadow and (4 shl BitIndex)) <> 0) and
          ((Samples[Index].Shadow and ($400 shl BitIndex)) <> 0) then
        begin
          Inc(ShadowedPixels);
          Break;
        end;
  Result := True;
end;

end.
