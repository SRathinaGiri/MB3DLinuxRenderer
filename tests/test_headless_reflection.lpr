program TestHeadlessReflection;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

uses
  SysUtils, TypeDefinitions, MB3DPortablePNG, MB3DHeadlessReflection;

procedure Fail(const MessageText: string);
begin
  WriteLn(StdErr, 'FAIL: ', MessageText);
  Halt(1);
end;

var
  Header: TMandHeader10;
  HeaderAddon: THeaderCustomAddon;
  LightVals: TLightVals;
  Samples: array[0..0] of TsiLight5;
  Pixels: TByteBuffer;
  ReflectedPixels: Integer;
  Status: THeadlessReflectionStatus;
  ModeName, ErrorText: string;
begin
  FillChar(Header, SizeOf(Header), 0);
  FillChar(HeaderAddon, SizeOf(HeaderAddon), 0);
  FillChar(LightVals, SizeOf(LightVals), 0);
  FillChar(Samples, SizeOf(Samples), 0);
  SetLength(Pixels, 3);
  Header.PCFAddon := @HeaderAddon;
  Header.bCalcSRautomatic := 1 or 2 or 4;
  Header.SRamount := 0.65;
  Header.SRreflectioncount := 3;
  Header.sTRIndex := 1.45;
  Header.sTransmissionAbsorption := 0.25;
  Header.sTRscattering := 0.5;
  Header.MCdiffReflects := 17;
  HeaderAddon.bOptions2 := 4;

  DescribeHeadlessReflection(Header, Status);
  if not Status.SavedEnabled then Fail('saved reflection flag was not detected');
  if not Status.Active then Fail('active reflection settings were not detected');
  if not Status.TransmissionEnabled then Fail('transmission flag was not detected');
  if not Status.TransmissionOnlyDIFS then Fail('only-dIFS transmission flag was not detected');
  if Abs(Status.TransmissionIndex - 1) > 0.000001 then
    Fail('inside-rendering override did not force transmission index to 1');
  if Status.ReflectionCount <> 3 then Fail('reflection count was not reported');
  if Status.DiffuseReflects <> 17 then Fail('diffuse-reflect setting was not reported');

  if not ApplyHeadlessReflection(Header, LightVals, Samples, Pixels, 1,
    hrmReport, Status, ModeName, ReflectedPixels, ErrorText) then
    Fail('report mode unexpectedly failed');
  if ModeName <> 'pending-recursive-post-pass' then
    Fail('active report mode returned unexpected mode');

  Header.bCalcSRautomatic := 0;
  if not ApplyHeadlessReflection(Header, LightVals, Samples, Pixels, 1,
    hrmPost, Status, ModeName, ReflectedPixels, ErrorText) then
    Fail('post mode should no-op when saved reflection is disabled');
  if ModeName <> 'disabled' then
    Fail('disabled reflection returned unexpected mode');

  WriteLn('PASS: headless reflection settings and guard');
end.
