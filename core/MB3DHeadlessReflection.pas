unit MB3DHeadlessReflection;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses TypeDefinitions;

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
  Mode: THeadlessReflectionMode; out Status: THeadlessReflectionStatus;
  out AppliedMode: string; out ErrorText: string): Boolean;

implementation

uses SysUtils;

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
  Mode: THeadlessReflectionMode; out Status: THeadlessReflectionStatus;
  out AppliedMode: string; out ErrorText: string): Boolean;
begin
  Result := True;
  ErrorText := '';
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

  AppliedMode := 'unsupported-recursive-post-pass';
  ErrorText := 'Saved specular reflection/transmission is enabled, but the ' +
    'headless recursive CalcSR post pass is not ported yet. Use ' +
    '--reflection report to render the current non-reflected parity image.';
  Result := False;
end;

end.
