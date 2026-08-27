unit MB3DResourceBundle;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses
  SysUtils;

type
  TMB3DResourceBundle = class
  private
    FRootDirectory: string;
    FFormulaDirectory: string;
    FLightMapDirectory: string;
    FFormulaCount: Integer;
    FLightMapCount: Integer;
    function CountFiles(const DirectoryName, Pattern: string): Integer;
  public
    function Load(const RootDirectory: string; out ErrorText: string): Boolean;
    property RootDirectory: string read FRootDirectory;
    property FormulaDirectory: string read FFormulaDirectory;
    property LightMapDirectory: string read FLightMapDirectory;
    property FormulaCount: Integer read FFormulaCount;
    property LightMapCount: Integer read FLightMapCount;
  end;

implementation

function TMB3DResourceBundle.CountFiles(const DirectoryName, Pattern: string): Integer;
var
  Search: TSearchRec;
begin
  Result := 0;
  if FindFirst(IncludeTrailingPathDelimiter(DirectoryName) + Pattern, faAnyFile, Search) <> 0 then
    Exit;
  try
    repeat
      if (Search.Name = '.') or (Search.Name = '..') or
         ((Search.Attr and faDirectory) <> 0) then
        Continue;
      Inc(Result);
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
end;

function TMB3DResourceBundle.Load(const RootDirectory: string;
  out ErrorText: string): Boolean;
begin
  Result := False;
  ErrorText := '';
  FRootDirectory := ExpandFileName(RootDirectory);
  FFormulaDirectory := IncludeTrailingPathDelimiter(FRootDirectory) + 'formulas';
  FLightMapDirectory := IncludeTrailingPathDelimiter(FRootDirectory) + 'lightmaps';
  FFormulaCount := 0;
  FLightMapCount := 0;
  if not DirectoryExists(FRootDirectory) then
  begin
    ErrorText := 'Asset root not found: ' + FRootDirectory;
    Exit;
  end;
  if not DirectoryExists(FFormulaDirectory) then
  begin
    ErrorText := 'Formula directory not found: ' + FFormulaDirectory;
    Exit;
  end;
  if not DirectoryExists(FLightMapDirectory) then
  begin
    ErrorText := 'Light-map directory not found: ' + FLightMapDirectory;
    Exit;
  end;
  FFormulaCount := CountFiles(FFormulaDirectory, '*.m3f');
  FLightMapCount := CountFiles(FLightMapDirectory, '*.png') +
    CountFiles(FLightMapDirectory, '*.jpg') +
    CountFiles(FLightMapDirectory, '*.jpeg') +
    CountFiles(FLightMapDirectory, '*.bmp') +
    CountFiles(FLightMapDirectory, '*.pgm');
  if FFormulaCount = 0 then
  begin
    ErrorText := 'No .m3f files found in ' + FFormulaDirectory;
    Exit;
  end;
  Result := True;
end;

end.
