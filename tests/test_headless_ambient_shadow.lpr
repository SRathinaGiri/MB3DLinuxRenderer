program TestHeadlessAmbientShadow;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

uses
  SysUtils, TypeDefinitions, MB3DHeadlessAmbientShadow;

procedure Fail(const MessageText: string);
begin
  WriteLn(StdErr, 'FAIL: ', MessageText);
  Halt(1);
end;

var
  Header: TMandHeader10;
  SamplesA, SamplesB: array[0..80] of TsiLight5;
  I, ShadowedA, ShadowedB: Integer;
  MeanA, MeanB: Single;
begin
  FillChar(Header, SizeOf(Header), 0);
  FillChar(SamplesA, SizeOf(SamplesA), 0);
  Header.Width := 9;
  Header.Height := 9;
  Header.dZoom := 1;
  Header.dFOVy := 45;
  Header.dZstart := 0;
  Header.dZend := 10;
  Header.dZmid := 0;
  Header.bCalcAmbShadowAutomatic := 25;
  Header.sAmbShadowThreshold := 1;
  Header.SSAORcount := 2;
  Header.bSSAO24BorderMirrorSize := 20;
  for I := 0 to High(SamplesA) do SamplesA[I].Zpos := 1000;
  SamplesA[40].Zpos := 900;
  SamplesA[80].Zpos := 32768;
  SamplesB := SamplesA;

  if not ApplyHeadlessAmbientShadow(Header, SamplesA, ShadowedA, MeanA) then
    Fail('24-bit radial pass rejected valid input');
  if not ApplyHeadlessAmbientShadow(Header, SamplesB, ShadowedB, MeanB) then
    Fail('repeat 24-bit radial pass rejected valid input');
  if SamplesA[40].AmbShadow = 0 then
    Fail('depth depression did not receive ambient shadow');
  if SamplesA[80].AmbShadow <> 0 then
    Fail('background pixel received ambient shadow');
  if (ShadowedA <> ShadowedB) or (Abs(MeanA - MeanB) > 0.000001) then
    Fail('radial pass is not reproducible');
  for I := 0 to High(SamplesA) do
    if SamplesA[I].AmbShadow <> SamplesB[I].AmbShadow then
      Fail(Format('radial pass differs at pixel %d', [I]));
  WriteLn('PASS: MB3D 24-bit radial ambient shadow');
end.
