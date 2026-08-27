program TestHeadlessFog;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

uses
  SysUtils, TypeDefinitions, MB3DPortablePNG, MB3DHeadlessShading;

procedure Fail(const MessageText: string);
begin
  WriteLn(StdErr, 'FAIL: ', MessageText);
  Halt(1);
end;

var
  Header: TMandHeader10;
  LightVals: TLightVals;
  Samples: array[0..0] of TsiLight5;
  Pixels: TByteBuffer;
  DirectionalLights, SkippedLights, DepthPixels, DynamicPixels: Integer;
  MeanDepth, MeanDynamic: Single;
begin
  FillChar(Header, SizeOf(Header), 0);
  FillChar(LightVals, SizeOf(LightVals), 0);
  FillChar(Samples, SizeOf(Samples), 0);
  Header.Width := 1;
  Header.Height := 1;
  Header.dZoom := 1;
  Header.dFOVy := 45;
  Header.dZstart := 0;
  Header.dZend := 10;
  Header.dZmid := 0;
  Header.Light.TBoptions := Cardinal(32) shl 23;
  Header.Light.DepthCol[0] := 10;
  Header.Light.DepthCol[1] := 10;
  Header.Light.DepthCol[2] := 10;
  Header.Light.DepthCol2 := Header.Light.DepthCol;
  Header.Light.DynFogR := 200;
  Header.Light.DynFogG := 20;
  Header.Light.DynFogB := 30;
  Header.Light.DynFogCol2[0] := 200;
  Header.Light.DynFogCol2[1] := 20;
  Header.Light.DynFogCol2[2] := 30;
  Samples[0].Zpos := 32768;
  Samples[0].Shadow := 10;
  LightVals.sDepth := 0.00001;
  LightVals.sShadGr := 0.1;
  LightVals.sDynFogMul := 0;
  LightVals.bDFogOptions := 1;

  ShadeMB3DFrame(Header, LightVals, Samples, False, Pixels,
    DirectionalLights, SkippedLights, DepthPixels, DynamicPixels,
    MeanDepth, MeanDynamic);

  if Length(Pixels) <> 3 then Fail('expected one RGB pixel');
  if DepthPixels <> 1 then Fail('depth fog was not applied');
  if DynamicPixels <> 1 then Fail('dynamic fog was not applied');
  if Abs(MeanDepth - 0.28) > 0.001 then
    Fail(Format('unexpected depth-fog mean %.6f', [MeanDepth]));
  if Abs(MeanDynamic - 1) > 0.001 then
    Fail(Format('unexpected dynamic-fog mean %.6f', [MeanDynamic]));
  if (Pixels[0] <> 200) or (Pixels[1] <> 20) or (Pixels[2] <> 30) then
    Fail(Format('unexpected fog color %d,%d,%d',
      [Pixels[0], Pixels[1], Pixels[2]]));
  WriteLn('PASS: legacy depth and two-color dynamic fog');
end.
