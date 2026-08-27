program MB3DWorker;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Math, TypeDefinitions, MB3DAnimationModel, MB3DAnimationHeaderAdapter,
  MB3DResourceBundle, MB3DCompiledFormulaCode, MB3DAnimationHeaderInterpolation,
  MB3DAnimationHeaderAddonInterpolation, MB3DOutputPlan,
  MB3DHeadlessCustomFormulas, MB3DHeadlessRenderer;

const
  ExitSuccess = 0;
  ExitInvalidArguments = 2;
  ExitInputFailure = 3;
  ExitRenderFailure = 5;

type
  TMB3DStereoRequest = (srOn, srOff);

  TWorkerRequest = record
    AnimationFile: string;
    OutputFile: string;
    AssetsDirectory: string;
    FrameNumber: Integer;
    ThreadCount: Integer;
    StereoRequest: TMB3DStereoRequest;
    OutputWidth: Integer;
    OutputHeight: Integer;
    CalculateHardShadows: Boolean;
  end;

procedure PrintUsage;
begin
  WriteLn('Usage: mb3d-worker --animation PATH --frame N --output PATH [--threads N] [--assets PATH] [--stereo on|off] [--size WIDTHxHEIGHT] [--shadows on|off]');
  WriteLn('       mb3d-worker --help | --version');
end;

function StereoRequestName(const StereoRequest: TMB3DStereoRequest): string;
begin
  case StereoRequest of
    srOn: Result := 'on';
  else
    Result := 'off';
  end;
end;

function JsonString(const Value: string): string;
begin
  Result := StringReplace(Value, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
end;

function FormulaNameFromBytes(const NameBytes: array of Byte): string;
var
  Index: Integer;
begin
  Result := '';
  for Index := Low(NameBytes) to High(NameBytes) do
  begin
    if NameBytes[Index] = 0 then
      Break;
    Result := Result + Chr(NameBytes[Index]);
  end;
end;

function VerifyAnimationFormulaFiles(const Animation: TMB3DAnimationModel;
  const Resources: TMB3DResourceBundle; out ExternalFormulaCount: Integer;
  out ErrorText: string): Boolean;
var
  KeyFrameIndex, FormulaIndex: Integer;
  HeaderAddon: THeaderCustomAddon;
  FormulaName, FormulaFile: string;
  FormulaCode: TMB3DCompiledFormulaCode;
begin
  Result := False;
  ExternalFormulaCount := 0;
  ErrorText := '';
  if SizeOf(HeaderAddon) <> MB3DAnimationV5HeaderAddonSize then
  begin
    ErrorText := 'Unsupported runtime header-addon layout';
    Exit;
  end;
  for KeyFrameIndex := 0 to Animation.KeyFrameCount - 1 do
  begin
    Move(Animation.KeyFrames[KeyFrameIndex].HeaderAddonBytes, HeaderAddon,
      SizeOf(HeaderAddon));
    for FormulaIndex := 0 to High(HeaderAddon.Formulas) do
      if (HeaderAddon.Formulas[FormulaIndex].iItCount <> 0) and
         (HeaderAddon.Formulas[FormulaIndex].iFnr > 9) then
      begin
        FormulaName := FormulaNameFromBytes(HeaderAddon.Formulas[FormulaIndex].CustomFname);
        if FormulaName <> '' then
        begin
          Inc(ExternalFormulaCount);
          FormulaFile := IncludeTrailingPathDelimiter(Resources.FormulaDirectory) +
            FormulaName + '.m3f';
          if not FileExists(FormulaFile) then
          begin
            ErrorText := Format('Missing formula "%s" for keyframe %d slot %d',
              [FormulaName, KeyFrameIndex, FormulaIndex]);
            Exit;
          end;
          if not LoadMB3DCompiledFormulaCode(FormulaFile, FormulaCode, ErrorText) then
          begin
            ErrorText := Format('Unable to load formula "%s" for keyframe %d slot %d: %s',
              [FormulaName, KeyFrameIndex, FormulaIndex, ErrorText]);
            Exit;
          end;
          FormulaCode.Free;
        end;
      end;
  end;
  Result := True;
end;

function RequireValue(const OptionName: string; var Index: Integer;
  out Value: string): Boolean;
begin
  Inc(Index);
  Result := Index <= ParamCount;
  if Result then
    Value := ParamStr(Index)
  else
    WriteLn(StdErr, 'Missing value for ', OptionName);
end;

function ParseRequest(out Request: TWorkerRequest): Integer;
var
  Index, Value: Integer;
  Argument, TextValue: string;
begin
  FillChar(Request, SizeOf(Request), 0);
  Request.ThreadCount := 1;
  Request.AssetsDirectory := 'assets';
  Request.StereoRequest := srOff;
  Request.CalculateHardShadows := True;
  Index := 1;
  while Index <= ParamCount do
  begin
    Argument := ParamStr(Index);
    if (Argument = '--help') or (Argument = '-h') then
    begin
      PrintUsage;
      Exit(ExitSuccess);
    end;
    if (Argument = '--version') then
    begin
      WriteLn('mb3d-worker 0.4.0 (headless RGB renderer)');
      Exit(ExitSuccess);
    end;
    if Argument = '--animation' then
    begin
      if not RequireValue(Argument, Index, Request.AnimationFile) then Exit(ExitInvalidArguments);
    end
    else if Argument = '--output' then
    begin
      if not RequireValue(Argument, Index, Request.OutputFile) then Exit(ExitInvalidArguments);
    end
    else if Argument = '--assets' then
    begin
      if not RequireValue(Argument, Index, Request.AssetsDirectory) then Exit(ExitInvalidArguments);
    end
    else if Argument = '--stereo' then
    begin
      if not RequireValue(Argument, Index, TextValue) then Exit(ExitInvalidArguments);
      if SameText(TextValue, 'on') then Request.StereoRequest := srOn
      else if SameText(TextValue, 'off') then Request.StereoRequest := srOff
      else
      begin
        WriteLn(StdErr, 'Invalid value for --stereo: ', TextValue,
          ' (expected on or off)');
        Exit(ExitInvalidArguments);
      end;
    end
    else if Argument = '--shadows' then
    begin
      if not RequireValue(Argument, Index, TextValue) then Exit(ExitInvalidArguments);
      if SameText(TextValue, 'on') then Request.CalculateHardShadows := True
      else if SameText(TextValue, 'off') then Request.CalculateHardShadows := False
      else
      begin
        WriteLn(StdErr, 'Invalid value for --shadows: ', TextValue,
          ' (expected on or off)');
        Exit(ExitInvalidArguments);
      end;
    end
    else if Argument = '--size' then
    begin
      if not RequireValue(Argument, Index, TextValue) then Exit(ExitInvalidArguments);
      Value := Pos('x', LowerCase(TextValue));
      if (Value < 2) or
        (not TryStrToInt(Copy(TextValue, 1, Value - 1), Request.OutputWidth)) or
        (not TryStrToInt(Copy(TextValue, Value + 1, MaxInt), Request.OutputHeight)) or
        (Request.OutputWidth < 1) or (Request.OutputHeight < 1) then
      begin
        WriteLn(StdErr, 'Invalid value for --size: ', TextValue,
          ' (expected WIDTHxHEIGHT)');
        Exit(ExitInvalidArguments);
      end;
    end
    else if (Argument = '--frame') or (Argument = '--threads') then
    begin
      if not RequireValue(Argument, Index, TextValue) then Exit(ExitInvalidArguments);
      if (not TryStrToInt(TextValue, Value)) or (Value < 0) then
      begin
        WriteLn(StdErr, 'Invalid value for ', Argument, ': ', TextValue);
        Exit(ExitInvalidArguments);
      end;
      if Argument = '--frame' then Request.FrameNumber := Value
      else if Value = 0 then
      begin
        WriteLn(StdErr, '--threads must be greater than zero');
        Exit(ExitInvalidArguments);
      end
      else Request.ThreadCount := Value;
    end
    else
    begin
      WriteLn(StdErr, 'Unknown option: ', Argument);
      Exit(ExitInvalidArguments);
    end;
    Inc(Index);
  end;
  if (Request.AnimationFile = '') or (Request.OutputFile = '') then
  begin
    WriteLn(StdErr, '--animation and --output are required');
    Exit(ExitInvalidArguments);
  end;
  if not FileExists(Request.AnimationFile) then
  begin
    WriteLn(StdErr, 'Animation file not found: ', Request.AnimationFile);
    Exit(ExitInputFailure);
  end;
  Result := -1;
end;

var
  Request: TWorkerRequest;
  ExitCode: Integer;
  Animation: TMB3DAnimationModel;
  Resources: TMB3DResourceBundle;
  Header: TMandHeader10;
  HeaderAddon: THeaderCustomAddon;
  FormulaStorage: array[0..5] of TCustomFormula;
  FormulaPointers: array[0..5] of Pointer;
  ExternalFormulaCount: Integer;
  ErrorText: string;
  StereoEnabled: Boolean;
  KeyFrameIndex, NextKeyFrameIndex, SubFrame: Integer;
  FramePosition: Double;
  InterpolatedHeaderBytes: TMB3DAnimationV5Header;
  InterpolatedHeaderAddonBytes: TMB3DAnimationV5HeaderAddon;
  InterpolatedFormulaCount: Integer;
  OutputPlan: TMB3DOutputPlan;
  RenderHeader: TMandHeader10;
  FormulaIndex: Integer;
begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow,
    exUnderflow, exPrecision]);
  ExitCode := ParseRequest(Request);
  if ExitCode = -1 then
  begin
    Animation := TMB3DAnimationModel.Create;
    Resources := TMB3DResourceBundle.Create;
    try
      if not Resources.Load(Request.AssetsDirectory, ErrorText) then
      begin
        WriteLn(StdErr, 'Unable to load assets: ', ErrorText);
        ExitCode := ExitInputFailure;
      end
      else if not Animation.LoadFromFile(Request.AnimationFile, ErrorText) then
      begin
        WriteLn(StdErr, 'Unable to load animation: ', ErrorText);
        ExitCode := ExitInputFailure;
      end
      else
      begin
        if not Animation.TryLocateFrame(Request.FrameNumber, KeyFrameIndex,
          SubFrame, ErrorText) then
        begin
          WriteLn(StdErr, 'Unable to resolve animation frame: ', ErrorText);
          ExitCode := ExitInputFailure;
        end
        else if not DecodeMB3DAnimationV5Header(Animation.KeyFrames[KeyFrameIndex].HeaderBytes,
          Header, ErrorText) then
        begin
          WriteLn(StdErr, 'Unable to decode selected keyframe header: ', ErrorText);
          ExitCode := ExitInputFailure;
        end
        else if not VerifyAnimationFormulaFiles(Animation, Resources,
          ExternalFormulaCount, ErrorText) then
        begin
          WriteLn(StdErr, 'Unable to resolve animation formulas: ', ErrorText);
          ExitCode := ExitInputFailure;
        end
        else
        begin
          NextKeyFrameIndex := KeyFrameIndex + 1;
          if NextKeyFrameIndex >= Animation.KeyFrameCount then
            if Animation.Looped then NextKeyFrameIndex := 0
            else NextKeyFrameIndex := KeyFrameIndex;
          FramePosition := SubFrame / Max(1, Animation.KeyFrames[KeyFrameIndex].FrameCount);
          InterpolateMB3DAnimationV5Header(Animation.KeyFrames[KeyFrameIndex].HeaderBytes,
            Animation.KeyFrames[NextKeyFrameIndex].HeaderBytes, FramePosition,
            InterpolatedHeaderBytes);
          InterpolateMB3DAnimationV5HeaderAddon(
            Animation.KeyFrames[KeyFrameIndex].HeaderAddonBytes,
            Animation.KeyFrames[NextKeyFrameIndex].HeaderAddonBytes, FramePosition,
            InterpolatedHeaderAddonBytes, InterpolatedFormulaCount);
          if not DecodeMB3DAnimationV5Header(InterpolatedHeaderBytes, Header, ErrorText) then
          begin
            WriteLn(StdErr, 'Unable to decode interpolated animation header: ', ErrorText);
            ExitCode := ExitInputFailure;
          end
          else
          begin
          if Request.OutputWidth > 0 then
          begin
            Header.Width := Request.OutputWidth;
            Header.Height := Request.OutputHeight;
          end;
          FillChar(HeaderAddon, SizeOf(HeaderAddon), 0);
          for FormulaIndex := 0 to High(FormulaPointers) do
            FormulaPointers[FormulaIndex] := @FormulaStorage[FormulaIndex];
          Move(InterpolatedHeaderAddonBytes, HeaderAddon, SizeOf(HeaderAddon));
          BindMB3DHeaderRuntimePointers(Header, HeaderAddon, FormulaPointers);
        SetMB3DFormulaDirectory(Resources.FormulaDirectory);
        StereoEnabled := Request.StereoRequest = srOn;
        OutputPlan := MakeMB3DOutputPlan(Request.OutputFile, StereoEnabled);
        WriteLn('MB3D_EVENT {"type":"assets","formulas":true,"lightmaps":true}');
        WriteLn('MB3D_EVENT {"type":"formulas","external":', ExternalFormulaCount, '}');
        for FormulaIndex := 0 to High(HeaderAddon.Formulas) do
          if HeaderAddon.Formulas[FormulaIndex].iItCount <> 0 then
          begin
            WriteLn('MB3D_EVENT {"type":"formula-slot","slot":', FormulaIndex,
              ',"name":"', JsonString(FormulaNameFromBytes(
                HeaderAddon.Formulas[FormulaIndex].CustomFname)),
              '","iterations":', HeaderAddon.Formulas[FormulaIndex].iItCount,
              ',"function":', HeaderAddon.Formulas[FormulaIndex].iFnr,
              ',"options":', HeaderAddon.Formulas[FormulaIndex].iOptionCount, '}');
          end;
        WriteLn('MB3D_EVENT {"type":"header","keyframe":', KeyFrameIndex,
          ',"subframe":', SubFrame, ',"width":', Header.Width,
          ',"height":', Header.Height, ',"calc3D":', Header.bCalc3D,
          ',"insideOptions":', HeaderAddon.bOptions2, ',"zStart":',
          FloatToStr(Header.dZstart), ',"zEnd":', FloatToStr(Header.dZend),
          ',"deStop":', FloatToStr(Header.sDEstop), ',"zoom":',
          FloatToStr(Header.dZoom), ',"ambientShadowMode":',
          Header.bCalcAmbShadowAutomatic, ',"hardShadowMode":',
          Header.bCalculateHardShadow, ',"hardShadowCalculated":',
          Header.bHScalculated, ',"dynamicFogIterations":', Header.bDFogIt,
          ',"gammaSetting":', (Header.Light.TBoptions shr 23) and $3F,
          ',"hardShadowMaxLength":',
          FloatToStr(Header.HSmaxLengthMultiplier), '}');
        WriteLn('MB3D_EVENT {"type":"interpolation","from":', KeyFrameIndex,
          ',"to":', NextKeyFrameIndex, ',"t":', FormatFloat('0.######', FramePosition),
          ',"formulas":', InterpolatedFormulaCount, '}');
        WriteLn('MB3D_EVENT {"type":"stereo","requested":"',
          StereoRequestName(Request.StereoRequest), '","savedHeaderMode":',
          Header.bStereoMode, ',"enabled":', LowerCase(BoolToStr(StereoEnabled, True)),
          ',"leftMode":4,"rightMode":3}');
        WriteLn('MB3D_EVENT {"type":"render-options","hardShadows":',
          LowerCase(BoolToStr(Request.CalculateHardShadows, True)), '}');
        if OutputPlan.Stereo then
          WriteLn('MB3D_EVENT {"type":"outputs","left":"', JsonString(OutputPlan.LeftFile),
            '","right":"', JsonString(OutputPlan.RightFile), '"}')
        else
          WriteLn('MB3D_EVENT {"type":"outputs","mono":"', JsonString(OutputPlan.MonoFile), '"}');
        WriteLn('MB3D_EVENT {"type":"started","frame":', Request.FrameNumber,
          ',"keyframes":', Animation.KeyFrameCount, '}');
        RenderHeader := Header;
        if OutputPlan.Stereo then
        begin
          if not RenderMB3DFrame(RenderHeader, 4, Request.ThreadCount,
            Request.CalculateHardShadows,
            OutputPlan.LeftFile, ErrorText) then
          begin
            WriteLn(StdErr, 'Left-eye render failed: ', ErrorText);
            ExitCode := ExitRenderFailure;
          end
          else
          begin
            WriteLn('MB3D_EVENT {"type":"eye-complete","eye":"left","output":"',
              JsonString(OutputPlan.LeftFile), '"}');
            RenderHeader := Header;
            if not RenderMB3DFrame(RenderHeader, 3, Request.ThreadCount,
              Request.CalculateHardShadows,
              OutputPlan.RightFile, ErrorText) then
            begin
              WriteLn(StdErr, 'Right-eye render failed: ', ErrorText);
              ExitCode := ExitRenderFailure;
            end
            else
            begin
              WriteLn('MB3D_EVENT {"type":"eye-complete","eye":"right","output":"',
                JsonString(OutputPlan.RightFile), '"}');
              ExitCode := ExitSuccess;
            end;
          end;
        end
        else if not RenderMB3DFrame(RenderHeader, 0, Request.ThreadCount,
          Request.CalculateHardShadows,
          OutputPlan.MonoFile, ErrorText) then
        begin
          WriteLn(StdErr, 'Render failed: ', ErrorText);
          ExitCode := ExitRenderFailure;
        end
        else
        begin
          WriteLn('MB3D_EVENT {"type":"complete","output":"',
            JsonString(OutputPlan.MonoFile), '"}');
          ExitCode := ExitSuccess;
        end;
          end;
        end;
      end;
    finally
      Resources.Free;
      Animation.Free;
    end;
  end;
  Halt(ExitCode);
end.
