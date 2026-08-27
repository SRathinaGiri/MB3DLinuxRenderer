unit MB3DMathTypes;
{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

type
  TSMatrix2 = array[0..1, 0..1] of Single;
  TMatrix3 = array[0..2, 0..2] of Double;
  TSMatrix3 = array[0..2, 0..3] of Single;
  TSMatrix4 = array[0..3, 0..3] of Single;
  TPSMatrix2 = ^TSMatrix2;
  TPMatrix3 = ^TMatrix3;
  TPSMatrix3 = ^TSMatrix3;
  TPSMatrix4 = ^TSMatrix4;
  TPos3D = array[0..2] of Double;
  TVec3D = array[0..2] of Double;
  TVec4D = array[0..3] of Double;
  TSVec = array[0..3] of Single;
  TPPos3D = ^TPos3D;
  TPVec3D = ^TVec3D;
  TPVec4D = ^TVec4D;
  TPSVec = ^TSVec;
  TSPoint = array[0..1] of Single;
  TPSPoint = ^TSPoint;
  TCAVWproc = procedure(V1, V2, V3: TPVec3D; const W: Double);
  TAVWproc = procedure(V1, V2: TPVec3D; const W: Double);
  T2Vproc = procedure(V1, V2: TPVec3D);
  T2Vproc4 = procedure(V1, V2: TPVec4D);
  TSVfunc = function(const V1: TSVec): TSVec;
  TSVfunc2 = function(const smin, smax: Single; const V1: TSVec): TSVec;
  TSVfunc3 = procedure(sv1: TPSVec);
  Double7B = array[0..6] of Byte;
  PDouble7B = ^Double7B;
  TQuaternion = array[0..3] of Double;
  TPQuaternion = ^TQuaternion;
  ShortFloat = array[0..1] of Shortint;
  PShortFloat = ^ShortFloat;
  TComplex = array[0..1] of Double;
  TPComplex = ^TComplex;
  T4Cardinal = array[0..3] of Cardinal;
  T4SVec = array[0..3] of TSVec;
  TP4SVec = ^T4SVec;
  T3SVec = array[0..2] of TSVec;
  TLNormals = array[0..2] of Smallint;
  TPLNormals = ^TLNormals;

implementation

end.
