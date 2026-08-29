unit MB3DHeadlessRenderer;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses TypeDefinitions, MB3DHeadlessAmbientShadow;

function RenderMB3DFrame(var Header: TMandHeader10; StereoMode,
  ThreadCount: Integer; CalculateHardShadows: Boolean;
  AmbientMode: THeadlessAmbientMode;
  const OutputFile: string; out ErrorText: string): Boolean;

implementation

uses Classes, SysUtils, Types, Math, Calc, HeaderTrafos, MB3DPortablePNG,
  MB3DHeadlessShading;

function RenderMB3DFrame(var Header: TMandHeader10; StereoMode,
  ThreadCount: Integer; CalculateHardShadows: Boolean;
  AmbientMode: THeadlessAmbientMode;
  const OutputFile: string; out ErrorText: string): Boolean;
var LightVals: TLightVals;
    Stats: TCalcThreadStats;
    StopRequested: LongBool;
    Samples: array of TsiLight5;
    Pixels: TByteBuffer;
    Rect: TRect;
    Index, HitCount, MinHitZ, MaxHitZ, DirectionalLights, SkippedLights,
    ShadowedPixels, HardShadowedPixels, HardShadowLights, LightIndex,
    DepthFoggedPixels, DynamicFoggedPixels: Integer;
    DESteps: Int64;
    MeanOcclusion, MeanDepthFog, MeanDynamicFog: Single;
    Options: TMB3DRenderOptions;
    PreviousHScalculated: Integer;
    AppliedAmbientMode: string;
begin
  Result := False;
  ErrorText := '';
  if (Header.Width <= 0) or (Header.Height <= 0) then
  begin
    ErrorText := 'Header has invalid image dimensions';
    Exit;
  end;
  if ThreadCount > 64 then ThreadCount := 64;
  if ThreadCount < 1 then ThreadCount := 1;
  Header.bStereoMode := StereoMode;
  FillChar(LightVals, SizeOf(LightVals), 0);
  FillChar(Stats, SizeOf(Stats), 0);
  StopRequested := False;
  Stats.pLBcalcStop := @StopRequested;
  SetLength(Samples, Header.Width * Header.Height);
  FillChar(Samples[0], Length(Samples) * SizeOf(TsiLight5), 0);
  Rect := Types.Rect(0, 0, Header.Width - 1, Header.Height - 1);
  MakeLightValsFromHeaderLight(@Header, @LightVals, 1, StereoMode);
  PreviousHScalculated := Header.bHScalculated;
  Options := MakeMB3DRenderOptions(ThreadCount, tpNormal);
  Options.CalculateHardShadows := CalculateHardShadows;
  if not CalcMandT(@Header, @LightVals, @Stats, @Samples[0],
    Header.Width * SizeOf(TsiLight5), 0, 0, Rect, Options) then
  begin
    if CalcLastError <> '' then ErrorText := CalcLastError
    else ErrorText := 'MB3D rejected the interpolated render parameters';
    Exit;
  end;
  DelayCalcPart(Stats.iTotalThreadCount, @Stats);
  if StopRequested then
  begin
    ErrorText := 'Rendering was cancelled';
    Exit;
  end;
  if CalculateHardShadows then
  begin
    if (Header.bCalc1HSsoft and 1) <> 0 then
      Header.bHScalculated := (PreviousHScalculated and 1) or
        Header.bCalculateHardShadow
    else
      Header.bHScalculated := (PreviousHScalculated and $FD) or
        Header.bCalculateHardShadow;
    MakeLightValsFromHeaderLight(@Header, @LightVals, 1, StereoMode);
  end;
  HitCount := 0;
  HardShadowedPixels := 0;
  HardShadowLights := 0;
  if CalculateHardShadows then
    for LightIndex := 0 to 5 do
      if (Header.bCalculateHardShadow and (4 shl LightIndex)) <> 0 then
        Inc(HardShadowLights);
  MinHitZ := 32767;
  MaxHitZ := 0;
  for Index := 0 to High(Samples) do
    if Samples[Index].Zpos < 32768 then
    begin
      Inc(HitCount);
      if Samples[Index].Zpos < MinHitZ then MinHitZ := Samples[Index].Zpos;
      if Samples[Index].Zpos > MaxHitZ then MaxHitZ := Samples[Index].Zpos;
      if CalculateHardShadows and (Samples[Index].SIgradient < 32768) then
        for LightIndex := 0 to 5 do
          if ((Header.bCalculateHardShadow and (4 shl LightIndex)) <> 0) and
            ((Samples[Index].Shadow and ($400 shl LightIndex)) <> 0) then
          begin
            Inc(HardShadowedPixels);
            Break;
          end;
    end;
  DESteps := 0;
  for Index := 1 to Stats.iTotalThreadCount do
    Inc(DESteps, Stats.CTrecords[Index].i64DEsteps);
  WriteLn('MB3D_EVENT {"type":"geometry","hits":', HitCount,
    ',"pixels":', Length(Samples), ',"minZ":', MinHitZ, ',"maxZ":', MaxHitZ,
    ',"deSteps":', DESteps, '}');
  if CalculateHardShadows then
    WriteLn('MB3D_EVENT {"type":"hard-shadow","mode":"formula-ray",',
      '"lights":', HardShadowLights, ',"shadowedPixels":',
      HardShadowedPixels, '}')
  else
    WriteLn('MB3D_EVENT {"type":"hard-shadow","mode":"disabled",',
      '"lights":0,"shadowedPixels":0}');
  if (Header.bCalcAmbShadowAutomatic and 1) <> 0 then
  begin
    if ApplyHeadlessAmbientShadow(Header, Samples, ShadowedPixels,
      MeanOcclusion, AmbientMode, AppliedAmbientMode) then
      if Pos('24bit', AppliedAmbientMode) > 0 then
        WriteLn('MB3D_EVENT {"type":"ambient-shadow","mode":"',
          AppliedAmbientMode, '",',
          '"passes":', Max(1, Header.SSAORcount), ',"shadowedPixels":',
          ShadowedPixels, ',"meanOcclusion":',
          FormatFloat('0.######', MeanOcclusion), '}')
      else
        WriteLn('MB3D_EVENT {"type":"ambient-shadow","mode":"',
        AppliedAmbientMode, '",',
        '"shadowedPixels":', ShadowedPixels, ',"meanOcclusion":',
        FormatFloat('0.######', MeanOcclusion), '}');
  end
  else
  begin
    for Index := 0 to High(Samples) do Samples[Index].AmbShadow := 0;
    WriteLn('MB3D_EVENT {"type":"ambient-shadow","mode":"disabled",',
      '"shadowedPixels":0,"meanOcclusion":0}');
  end;
  ShadeMB3DFrame(Header, LightVals, Samples, CalculateHardShadows, Pixels,
    DirectionalLights, SkippedLights, DepthFoggedPixels, DynamicFoggedPixels,
    MeanDepthFog, MeanDynamicFog);
  WriteLn('MB3D_EVENT {"type":"shading","mode":"rgb","directionalLights":',
    DirectionalLights, ',"unsupportedLights":', SkippedLights, '}');
  WriteLn('MB3D_EVENT {"type":"fog","mode":"depth-and-dynamic",',
    '"depthPixels":', DepthFoggedPixels, ',"meanDepth":',
    FormatFloat('0.######', MeanDepthFog), ',"dynamicPixels":',
    DynamicFoggedPixels, ',"meanDynamic":',
    FormatFloat('0.######', MeanDynamicFog), ',"dynamicIterations":',
    Header.bDFogIt, '}');
  Result := SaveRGB8PNG(OutputFile, Header.Width, Header.Height, Pixels, ErrorText);
end;

end.
