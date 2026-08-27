unit MB3DOutputPlan;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

type
  TMB3DOutputPlan = record
    Stereo: Boolean;
    MonoFile: string;
    LeftFile: string;
    RightFile: string;
  end;

function MakeMB3DOutputPlan(const OutputFile: string; const Stereo: Boolean): TMB3DOutputPlan;

implementation

uses
  SysUtils;

function AddEyeSuffix(const FileName, EyeSuffix: string): string;
var
  Extension: string;
begin
  Extension := ExtractFileExt(FileName);
  if Extension = '' then
    Result := FileName + EyeSuffix + '.png'
  else
    Result := ChangeFileExt(FileName, '') + EyeSuffix + Extension;
end;

function MakeMB3DOutputPlan(const OutputFile: string; const Stereo: Boolean): TMB3DOutputPlan;
begin
  Result.Stereo := Stereo;
  Result.MonoFile := '';
  Result.LeftFile := '';
  Result.RightFile := '';
  if Stereo then
  begin
    Result.LeftFile := AddEyeSuffix(OutputFile, '-L');
    Result.RightFile := AddEyeSuffix(OutputFile, '-R');
  end
  else
    Result.MonoFile := OutputFile;
end;

end.
