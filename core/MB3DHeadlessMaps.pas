unit MB3DHeadlessMaps;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses TypeDefinitions, Math3D;

type
  TVLMP = function(vd: TPVec3D): LongBool;
  TVLMV = function(vd: TPSVec): Single;

  TVolumetricLightMap = packed record
    CubeSize, HalfSize: Integer;
    SizeFactor, CsizeS, HSizeS: Single;
    SideCount: Integer;
    StretchSide1: Single;
    HeightS2to5: Integer;
    MinDistance: Single;
    IsPosLight, Rotate: LongBool;
    sFree: Single;
    LightPos: TVec3D;
    RotMatrix: TSMatrix3;
    CubeSides: array[0..5] of array of Single;
  end;

function LoadLightMapNr(nr: Integer; LMap: TPLightMap): LongBool;
procedure FreeLightMap(LM: TPLightMap);
function VolLightMapPosPas(vd: TPVec3D): LongBool;
function GetVolLightMapVecPas(vd: TPSVec): Single;

var
  VolumeLightMap: TVolumetricLightMap;
  VolLightMapPos: TVLMP = VolLightMapPosPas;
  GetVolLightMapVec: TVLMV = GetVolLightMapVecPas;

implementation

function LoadLightMapNr(nr: Integer; LMap: TPLightMap): LongBool;
begin
  { Image-map loading is deliberately separate from the first portable
    ray-marching milestone. Callers treat zeroed/missing maps as unavailable. }
  if LMap <> nil then
    FillChar(LMap^, SizeOf(LMap^), 0);
  Result := False;
end;

procedure FreeLightMap(LM: TPLightMap);
begin
  if LM = nil then Exit;
  SetLength(LM.LMa, 0);
  FillChar(LM^, SizeOf(LM^), 0);
end;

function VolLightMapPosPas(vd: TPVec3D): LongBool;
begin
  Result := False;
end;

function GetVolLightMapVecPas(vd: TPSVec): Single;
begin
  Result := 0;
end;

end.
