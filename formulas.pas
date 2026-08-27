unit formulas;
{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}


interface

uses TypeDefinitions;

procedure doHybridPas(PIteration3D: TPIteration3D);
function doHybridPasDE(PIteration3D: TPIteration3D): Double;
procedure doHybridSSE2(PIteration3D: TPIteration3D);
function doHybridDESSE2(PIteration3D: TPIteration3D): Double;
procedure doInterpolHybridPas(PIteration3D: TPIteration3D);
procedure doInterpolHybridSSE2(PIteration3D: TPIteration3D);
function doInterpolHybridPasDE(PIteration3D: TPIteration3D): Double;
function doInterpolHybridDESSE2(PIteration3D: TPIteration3D): Double;
procedure doInterpolHybridPas4D(PIteration3D: TPIteration3D);
function doInterpolHybridPas4DDE(PIteration3D: TPIteration3D): Double;
//function doInterpolHybridPasIFS(PIteration3D: TPIteration3D): Double;
procedure doHybrid4DPas(PIteration3D: TPIteration3D);
procedure doHybrid4DSSE2(PIteration3D: TPIteration3D);
function doHybrid4DDEPas(PIteration3D: TPIteration3D): Double;
function doHybridIFS3D(PIteration3D: TPIteration3D): Double;
function doHybridIFS3DnoVecIni(PIteration3D: TPIteration3D): Double; //to use behind common fractals, use the new vec for it

procedure HybridCube(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridCubeDE(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridCubeSSE2(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridCubeSSE2DE(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridItTricorn(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridQuat(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridItIntPow2(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridItIntPow3(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridItIntPow4(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridIntP5(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridIntP6(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridIntP7(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridIntP8(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridQuatSSE2(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridItIntPow2SSE2(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridCustomIFS;
procedure TestHybrid(var x, y, z, w: Double; PIteration3D: TPIteration3D); //available if 't' pressed on intern formula
procedure HybridCustomIFStest;

procedure HybridFloatPow(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure HybridSuperCube2(var x, y, z, w: Double; PIteration3D: TPIteration3D);   //Bulbox
procedure HybridFolding(var x, y, z, w: Double; PIteration3D: TPIteration3D);
procedure EmptyFormula(var x, y, z, w: Double; PIteration3D: TPIteration3D); //for not used formulas
procedure HybridItIntPow2scale(var x, y, z, w: Double; PIteration3D: TPIteration3D); //sine bulb with scaling
procedure CalcSmoothIterations(PIt3D: TPIteration3D; n: Integer);
procedure AexionC(var x, y, z, w: Double; PIteration3D: TPIteration3D);

var
    fIsMemberAlternating:   TMandFunction   = doHybridPas;
    fIsMemberAlternatingDE: TMandFunctionDE = doHybridPasDE;
    fIsMemberAlternating4D: TMandFunction   = doHybrid4DPas;
    fIsMemberIpol:          TMandFunction   = doInterpolHybridPas;
    fIsMemberIpolDE:        TMandFunctionDE = doInterpolHybridPasDE;
    fHybridCubeDE:    ThybridIteration = HybridCubeDE;
    fHybridCube:      ThybridIteration = HybridCube;
    fHybridQuat:      ThybridIteration = HybridQuat;
    fHybridItIntPow2: ThybridIteration = HybridItIntPow2;
    fHybridTricorn:   ThybridIteration = HybridItTricorn;
    fHIntFunctions:   array[2..8] of ThybridIteration = (HybridItIntPow2,
      HybridItIntPow3, HybridItIntPow4, HybridIntP5, HybridIntP6, HybridIntP7,
      HybridIntP8);

 {   testhybridDEoption: Integer = 2; //6;  //11=ABox  5=4dABox  6=4dIFS
    testhybridRstop: Double = 1024;    //1024
    testhybridDEscale: Double = 0.2;   //0.2;
    testhybridPow: Double = 2;            //0,7,0    21: .SRECI2 single + reciproc single
    testhybridOptionCount: Integer = 14;   //AmazingBox vars: scale=double, MinR=boxscale: Scale/Sqr(MinR), Sqr(MinR), Fold=double..
    testhybridOptionTypes: array[0..13] of Integer = (1,1,9,1,1,1,1,1,1,6,6,6,1,1);  //5:.3DoubleAngles  9:DSquare
    testhybridOptionVals: array[0..13] of Double = (2,0.25,0.5,2,2,2,1,1,1,0,0,0,2,2);
    testhybridOptionsStrings: array[0..13] of String = ('Scale','BoxFold','SphereFold','NonLin X','NonLin Y','NonLin Z','Lin X','Lin Y',
      'Lin Z','Rotate X','Rotate Y','Rotate Z', 'NonLin vary', 'Lin vary'); }
{.Double Scale = 1.5      asurf
.Boxscale Min R = 0.5
.Double Fold = 1
.3SingleAngles Rotation1 = 5
.Double Scale vary = 0
.Integer Sphere or Cylinder = 1   }
 {   testhybridDEoption: Integer = 2;  //abox platinum
    testhybridRstop: Double = 1024;
    testhybridDEscale: Double = 0.2;
    testhybridPow: Double = 2;            //0,7,0    21: .SRECI2 single + reciproc single
    testhybridOptionCount: Integer = 15;   //AmazingBox vars: scale=double, MinR=boxscale: Scale/Sqr(MinR), Sqr(MinR), Fold=double..
    testhybridOptionTypes: array[0..14] of Integer = (0,7,0,6,6,6,0,0,0,13,3,3,3,3,2);  //6:.3SingleAngles  9:DSquare
    testhybridOptionVals: array[0..14] of Double = (2,0.5,1,0,0,0,0,0,0,1,0,0,0,0,0);
    testhybridOptionsStrings: array[0..14] of String = ('Scale','Min R/IR','Fold','RotationX','RotationY','RotationZ',
      'Inv xC','Inv yC','Inv zC','Inv Radius','FoldX, XY angle','FoldX, XZ angle','FoldY, XY angle','FoldY, YZ angle',
      'Abs XYZ switches');   }
    testhybridDEoption: Integer = -1;  //X+SinY
    testhybridRstop: Double = 16;
    testhybridDEscale: Double = 0.2;
    testhybridPow: Double = 2;            //0,7,0    21: .SRECI2 single + reciproc single
    testhybridOptionCount: Integer = 6;   //AmazingBox vars: scale=double, MinR=boxscale: Scale/Sqr(MinR), Sqr(MinR), Fold=double..
    testhybridOptionTypes: array[0..5] of Integer = (2,2,1,1,1,1);  //6:.3SingleAngles  9:DSquare
    testhybridOptionVals: array[0..5] of Double = (1,2,0,1,1,0);
    testhybridOptionsStrings: array[0..5] of String = ('Index1','Index2','Offset 1','Scale 1','Scale 2','Offset 2');
{.Double Scale = 2
.Boxscale MinR/IR = 0.5
.Double Fold = 1
.3SingleAngles Rotate = 0
.Double Inv xC = 0
.Double Inv yC = 0
.Double Inv zC = 0
.DRecipro Inv Radius = 1
.DoubleAngle FoldX, XY angle = 0
.DoubleAngle FoldX, XZ angle = 0
.DoubleAngle FoldY, XY angle = 0
.DoubleAngle FoldY, YZ angle = 0
.Integer Abs XYZ switches = 0 }{   testhybridDEoption: Integer = 11;  //amazing surf
    testhybridRstop: Double = 20;
    testhybridDEscale: Double = 0.2;
    testhybridPow: Double = 2;            //0,7,0    21: .SRECI2 single + reciproc single
    testhybridOptionCount: Integer = 8;   //AmazingBox vars: scale=double, MinR=boxscale: Scale/Sqr(MinR), Sqr(MinR), Fold=double..
    testhybridOptionTypes: array[0..7] of Integer = (0,7,0,6,6,6,0,2);  //6:.3SingleAngles  9:DSquare
    testhybridOptionVals: array[0..7] of Double = (1.5,0.5,1,5,5,5,0,1);
    testhybridOptionsStrings: array[0..7] of String = ('Scale','Min R','Fold','Roatation','','','Scale vary','Sphere or Cylinder');
{    testhybridDEoption: Integer = 11;   //smoothbox
    testhybridRstop: Double = 1024;    //1024
    testhybridDEscale: Double = 0.2;   //0.2;
    testhybridPow: Double = 2;            //0,7,0    21: .SRECI2 single + reciproc single
    testhybridOptionCount: Integer = 8;   //AmazingBox vars: scale=double, MinR=boxscale: Scale/Sqr(MinR), Sqr(MinR), Fold=double..
    testhybridOptionTypes: array[0..7] of Integer = (0,7,0,0,2,0,2,0);  //5:.3DoubleAngles  9:DSquare
    testhybridOptionVals: array[0..7] of Double = (2,0.5,1,0,6,1,4,0.3);
    testhybridOptionsStrings: array[0..7] of String = ('Scale','Min R','Fold','Scale vary','Sharpness (Integer 2+)',
      'Fix (BoxFold)','Sh. of BallFold (Int 3+)','Fix (BallFold)');     }

const  cs05: Single = 0.5;
       cs099: Single = 0.99;
       testIFSDEoption: Integer = 20;
       testIFSOptionCount: Integer = 10;  //Plane with otrap map coloring
       testIFSOptionTypes: array [0..9] of Integer = (0,0,0,0,0,2,2,1,1,2);
       testIFSOptionVals: array [0..9] of Double = (0,1,0,0,1,0,0,0,1,0);
       testIFSOptionsStrings: array [0..9] of String = ('Normal Z','Normal Y','Normal X','Offset','Scale',
         'Otrap color map','Map channel','Otrap offset','Otrap scale', 'Solid (0,1)'); // }
{       testIFSDEoption: Integer = 20;
       testIFSOptionCount: Integer = 13;  //Sphere
       testIFSOptionTypes: array [0..12] of Integer = (0,14,14,0,14,13,13,13,2,2,1,1,0);   //.3SingleAngles = 6  .2Doubles = 14  .Integer = 2
       testIFSOptionVals: array [0..12] of Double = (1,2,0,0,3,1,1,1,1,0,1,1,0);  // .SINGLEANGLE = 4 (sin,cos)  .DSqrReci = 15
       testIFSOptionsStrings: array [0..12] of String = ('Radius','Scale','Z add','Y add','X add',  //.DRECIPRO = 13
         'Z size','Y size','X size','Apply add+scale','Otrap option','Otrap offset','Otrap scale',
         'Inside radius'); // }
   {    testIFSDEoption: Integer = 20;
       testIFSOptionCount: Integer = 9;  //Box rounded
       testIFSOptionTypes: array [0..8] of Integer = (0,0,0,14,14,0,0,14,2);   //.3SingleAngles = 6  .2Doubles = 14  .Integer = 2
       testIFSOptionVals: array [0..8] of Double = (1,1,1,2,0,1,1,0.1,1);  // .SINGLEANGLE = 4 (sin,cos)  .DSqrReci = 15
       testIFSOptionsStrings: array [0..8] of String = ('Z halfwidth','Y halfwidth','X halfwidth',
         'Scale','Z add','Y add','X add','Border','Apply add+scale'); // }
      { testIFSDEoption: Integer = 20;
       testIFSOptionCount: Integer =14;  //sphere map
       testIFSOptionTypes: array [0..13] of Integer = (2,2,1,1,1,1,1,1,6,6,6,2,1,1);   //4=SINGLEANGLE    1=single
       testIFSOptionVals: array [0..13] of Single = (10,0,0,0,0,1,1,0.35,0,0,0,1,0,1);
       testIFSOptionsStrings: array [0..13] of String =      //spheremap/Heightmap: col-nr position changed!
       ('Map nr', 'Col nr', 'Xoffset', 'Yoffset', 'Zoffset', 'Xscale', 'Yscale', 'Hscale',
       'Rotation', 'Rotation', 'Rotation', 'OTrap Color nr', 'Color offset', 'Color mult');  }
     {   testIFSDEoption: Integer = 20;
       testIFSOptionCount: Integer = 15;  //HeightMapSphere with OTrap
       testIFSOptionTypes: array [0..14] of Integer = (2,2,1,1,1,1,1,1,18,1,1,1,2,1,1);
       testIFSOptionVals: array [0..14] of Single = (10,0,0,0,0,1,1,0.35,1,0,0,0,1,0,1);
       testIFSOptionsStrings: array [0..14] of String = ('Map nr', 'Map channel', 'X off',
       'Y off', 'Z off', 'Length', 'Radius', 'Map height', 'Scale', 'X rot', 'Y rot', 'Z rot'
       , 'OTrap channel','OTrap offset', 'OTrap mul');    }

implementation

uses Math, Math3D, SysUtils;

procedure HybridCustomIFStest;
begin
  // Placeholder: custom IFS is not supported without register-based context.

end;

procedure ipow2(var x, y: Double);  //x:=x*x-y*y   y:=2xy
var
  xt, yt: Double;
begin
    xt := x;
    yt := y;
    y := 2 * xt * yt;
    x := xt * xt - yt * yt;
end;

procedure ComplexSqr(var xy: TComplex);  //x:=x*x-y*y   y:=2xy
var
  xt, yt: Double;
begin
    xt := xy[0];
    yt := xy[1];
    xy[1] := 2 * xt * yt;
    xy[0] := xt * xt - yt * yt;
end;

function ComplexMul(c1, c2: TComplex): TComplex;  //r[0] := x1*x2-y1*y2   r[1]:=x1*y2+x2*y1
begin
    Result[0] := c1[0] * c2[0] - c1[1] * c2[1];
    Result[1] := c1[0] * c2[1] + c1[1] * c2[0];
end;

function ComplexSqr2(c1: TComplex): TComplex;
begin
    Result[0] := c1[0] * c1[0] - c1[1] * c1[1];
    Result[1] := 2 * c1[0] * c1[1];
end;

function CConj(c1: TComplex): TComplex;
begin
    Result[0] := c1[0];
    Result[1] := -c1[1];
end;

function ComplexPower(cB, cE: TComplex): TComplex;
var c1, c2: TComplex;
    s, c, d: Double;
begin
    c1[0] := 0.5 * Ln(Sqr(cB[0]) + Sqr(cB[1]));
    c1[1] := ArcTan2(cB[1], cB[0]);
    c2[0] := cE[0] * c1[0] - cE[1] * c1[1];
    c2[1] := cE[0] * c1[1] + cE[1] * c1[0];
    d := Exp(c2[0]);
    SinCosD(c2[1], s, c);
    Result[0] := c * d;
    Result[1] := s * d;
end;

function ComplexSub(c1, c2: TComplex): TComplex;
begin
    Result[0] := c1[0] - c2[0];
    Result[1] := c1[1] - c2[1];
end;

function ComplexAdd(c1, c2: TComplex): TComplex;
begin
    Result[0] := c1[0] + c2[0];
    Result[1] := c1[1] + c2[1];
end;

function ComplexScale(c1: TComplex; d: Double): TComplex;
begin
    Result[0] := c1[0] * d;
    Result[1] := c1[1] * d;
end;

procedure QuatRotate(v: TPVec3D; q: TQuaternion);
var //w: TVec3D;
    w, x, y, z: Double;
begin
  {  w := v;
    v[0] := w[0] * (1 - 2 * (Sqr(q[1]) - Sqr(q[2]))) + w[1] * () + w[2] * ();
    v[1] := w[0] * () + w[1] * () + w[2] * ();
    v[2] := w[0] * () + w[1] * () + w[2] * ();   }

    w := -q[0] * v[0] - q[1] * v[1] - q[2] * v[2];
    x := q[3] * v[0] + q[1] * v[2] - q[2] * v[1];
    y := q[3] * v[1] - q[0] * v[2] + q[2] * v[0];
    z := q[3] * v[2] + q[0] * v[1] - q[1] * v[0];

    v[0] := (w * -q[0] + x * q[3] - y * q[2] + z * q[1]);
    v[1] := (w * -q[1] + x * q[2] + y * q[3] - z * q[0]);
    v[2] := (w * -q[2] - x * q[1] + y * q[0] + z * q[3]);
end;

procedure QuatMultiply(q1, q2: TPQuaternion);
var qt: TQuaternion;
begin
    qt := q1^;
    q1[3] := (qt[3]*q2[3] - qt[0]*q2[0] - qt[1]*q2[1] - qt[2]*q2[2]);
    q1[0] := (qt[3]*q2[0] + qt[0]*q2[3] + qt[1]*q2[2] - qt[2]*q2[1]);
    q1[1] := (qt[3]*q2[1] - qt[0]*q2[2] + qt[1]*q2[3] + qt[2]*q2[0]);
    q1[2] := (qt[3]*q2[2] + qt[0]*q2[1] - qt[1]*q2[0] + qt[2]*q2[3]);
end;

function Heart(x, y, z: Double): Double;
var xx, yy, zz, a: Double;
begin
  xx := x*x;
  yy := y*y;
  zz := z*z;
  a := 2*xx + yy + zz - 1;
  a := a*a*a;
  zz := zz * z;
  Result := a - 0.1 * xx * zz - yy * zz;
end;

procedure TestHybrid(var x, y, z, w: Double; PIteration3D: TPIteration3D); //available if 't' pressed on intern formula
begin
  HybridCube(x, y, z, w, PIteration3D);
end;

procedure doInterpolHybridPas(PIteration3D: TPIteration3D); //interpolate between 2 formulas. nHybrid[n] is single-weight
var X1, Y1: TVec4D;                                         //new ext version
    XX, YY: Double;  
    S1, S2: Single;
begin
    with TPIteration3Dext(Integer(PIteration3D) - 56)^ do
    begin
      if DoJulia then mCopyVec(@J1, @JU1) else mCopyVec(@J1, @C1);
      mCopyVec(@x, @C1);
      w := 0;
      Rout  := x * x + y * y + z * z;
      OTrap := Rout;
      bFirstIt  := 0;
      ItResultI := 0;
      S1 := PSingle(@nHybrid[0])^;
      S2 := PSingle(@nHybrid[1])^;
      repeat
        Rold := Rout;
        mCopyVec4(@Y1, @x);
        PVar := fHPVar[0];
        fHybrid[0](x, y, z, w, PIteration3D);
        mCopyVec4(@x1, @x);
        mCopyVec4(@x, @Y1);
        PVar := fHPVar[1];
        fHybrid[1](x, y, z, w, PIteration3D);
        XX := Sqrt(Sqr(x1[0]) + Sqr(x1[1]) + Sqr(x1[2]));
        YY := Sqrt(x * x + y * y + z * z);
        XX := XX * S1 + YY * S2;
        x := x1[0] * S1 + x * S2;
        y := x1[1] * S1 + y * S2;
        z := x1[2] * S1 + z * S2;
        w := x1[3] * S1 + w * S2;
        YY := XX / Sqrt(x * x + y * y + z * z + 1e-40);
        x := x * YY;
        y := y * YY;
        z := z * YY;
        Inc(ItResultI);
        Rout := XX * XX;
        if Rout < OTrap then OTrap := Rout;
      until
        (ItResultI >= maxIt) or (Rout > RStop);
      if CalcSIT then CalcSmoothIterations(PIteration3D, 0);
    end;
end;

procedure doInterpolHybridSSE2(PIteration3D: TPIteration3D);   // new ext version 
begin
  doInterpolHybridPas(PIteration3D);
end;

function doInterpolHybridPasDE(PIteration3D: TPIteration3D): Double;
var X1, Y1: TVec4D;                                     
    XX, YY: Double;  
    S1, S2: Single;
begin
    with TPIteration3Dext(Integer(PIteration3D) - 56)^ do
    begin
      if DoJulia then mCopyVec(@J1, @JU1) else mCopyVec(@J1, @C1);
      mCopyVec(@x, @C1);
      Rout  := x * x + y * y + z * z;
      OTrap := Rout;
      if (DEoption and $18) = 16 then w := Rout else w := 1;
      S1 := PSingle(@nHybrid[0])^;
      S2 := PSingle(@nHybrid[1])^;
      bFirstIt  := 0;
      ItResultI := 0;
      repeat
        Rold := Rout;
        mCopyVec4(@Y1, @x);
        PVar := fHPVar[0];
        fHybrid[0](x, y, z, w, PIteration3D);
        mCopyVec4(@x1, @x);
        mCopyVec4(@x, @Y1);
        PVar := fHPVar[1];
        fHybrid[1](x, y, z, w, PIteration3D);
        XX := Sqrt(Sqr(x1[0]) + Sqr(x1[1]) + Sqr(x1[2]));
        YY := Sqrt(x * x + y * y + z * z);
        XX := XX * S1 + YY * S2;
        x := x1[0] * S1 + x * S2;
        y := x1[1] * S1 + y * S2;
        z := x1[2] * S1 + z * S2;
        w := Abs(x1[3]) * S1 + Abs(w) * S2;
        YY := XX / Sqrt(x * x + y * y + z * z + 1e-40);
        x := x * YY;
        y := y * YY;
        z := z * YY;
        Inc(ItResultI);
        Rout := XX * XX;
        if Rout < OTrap then OTrap := Rout;
      until
        (ItResultI >= maxIt) or (Rout > RStop);

      case DEoption and 7 of
        4: Result := Abs(z) * Ln(Abs(z)) / w; //Julia?
        7: Result := Sqrt(Rout / RStop) * Power(PDouble(Integer(PVar) - 16)^, -ItResultI);    //Pvar does only work for single formula
      else Result := Sqrt(Rout) / Abs(w);   //AmBox + IFS
      end;     // distance = 0.5 * r * log(r) / r_dz;  for analytical powers!

      if CalcSIT then CalcSmoothIterations(PIteration3D, 0);
    end;
end;

function doInterpolHybridDESSE2(PIteration3D: TPIteration3D): Double;   // new ext version
begin
  Result := doInterpolHybridPasDE(PIteration3D);
end;

procedure doInterpolHybridPas4D(PIteration3D: TPIteration3D);
var X1, Y1: TVec4D;                                     
    XX, YY: Double;  
    S1, S2: Single;
begin
    with TPIteration3Dext(Integer(PIteration3D) - 56)^ do
    begin
      Rotate4Dex(@C1, @x, @SMatrix4);
      if DoJulia then
      begin
        mCopyVec(@J1, @JU1);
        J4 := Ju4;
      end
      else
      begin
        mCopyVec(@J1, @x);
        J4 := w;
      end;
      Rout := x*x + y*y + z*z + w*w;
      OTrap := Rout;
      bFirstIt := 0;
      ItResultI := 0;
      S1 := PSingle(@nHybrid[0])^;
      S2 := PSingle(@nHybrid[1])^;
      repeat
        Rold := Rout;
        mCopyVec4(@Y1, @x);
        PVar := fHPVar[0];
        fHybrid[0](x, y, z, w, PIteration3D);
        mCopyVec4(@x1, @x);
        mCopyVec4(@x, @Y1);
        PVar := fHPVar[1];
        fHybrid[1](x, y, z, w, PIteration3D);
        XX := Sqrt(Sqr(x1[0]) + Sqr(x1[1]) + Sqr(x1[2]) + Sqr(x1[3]));
        YY := Sqrt(x*x + y*y + z*z + w*w);
        XX := XX * S1 + YY * S2;
        x := x1[0] * S1 + x * S2;
        y := x1[1] * S1 + y * S2;
        z := x1[2] * S1 + z * S2;
        w := x1[3] * S1 + w * S2;
        YY := XX / Sqrt(x*x + y*y + z*z + w*w + 1e-40);
        x := x * YY;
        y := y * YY;
        z := z * YY;
        w := w * YY;
        Inc(ItResultI);
        Rout := XX * XX;
        if Rout < OTrap then OTrap := Rout;
      until
        (ItResultI >= maxIt) or (Rout > RStop);
      if CalcSIT then CalcSmoothIterations(PIteration3D, 0);
    end;
end;

function doInterpolHybridPas4DDE(PIteration3D: TPIteration3D): Double;
var X1, Y1: TVec4D;                                     
    XX, YY, DT, DD: Double;
    S1, S2: Single;
begin
    with TPIteration3Dext(Integer(PIteration3D) - 56)^ do
    begin
      Rotate4Dex(@C1, @x, @SMatrix4);
      if DoJulia then
      begin
        mCopyVec(@J1, @JU1);
        J4 := Ju4;
      end
      else
      begin
        mCopyVec(@J1, @x);
        J4 := w;
      end;
      Rout := x*x + y*y + z*z + w*w;
      OTrap := Rout;
      bFirstIt := 0;
      ItResultI := 0;
      case (DEoption and $38) of
        16:  Deriv1 := Rout;
        32:  begin Deriv1 := 1; Deriv2 := 0; Deriv3 := 0; end;
      else Deriv1 := 1;
      end;
      S1 := PSingle(@nHybrid[0])^;
      S2 := PSingle(@nHybrid[1])^;
      repeat
        Rold := Rout;
        mCopyVec4(@Y1, @x);
        DT := Deriv1;
        PVar := fHPVar[0];
        fHybrid[0](x, y, z, w, PIteration3D);
        mCopyVec4(@x1, @x);
        mCopyVec4(@x, @Y1);
        DD := Deriv1;
        Deriv1 := DT;
        PVar := fHPVar[1];
        fHybrid[1](x, y, z, w, PIteration3D);
        XX := Sqrt(Sqr(x1[0]) + Sqr(x1[1]) + Sqr(x1[2]) + Sqr(x1[3]));
        YY := Sqrt(x*x + y*y + z*z + w*w);
        XX := XX * S1 + YY * S2;
        x := x1[0] * S1 + x * S2;
        y := x1[1] * S1 + y * S2;
        z := x1[2] * S1 + z * S2;
        w := x1[3] * S1 + w * S2;
        Deriv1 := Abs(DD) * S1 + Abs(Deriv1) * S2;
        YY := XX / Sqrt(x*x + y*y + z*z + w*w + 1e-40);
        x := x * YY;
        y := y * YY;
        z := z * YY;
        w := w * YY;
        Inc(ItResultI);
        Rout := XX * XX;
        if Rout < OTrap then OTrap := Rout;
      until
        (ItResultI >= maxIt) or (Rout > RStop);
      case DEoption and 7 of                      //and 38 = 32...
        4: Result := Abs(z) * Ln(Abs(z)) / Deriv1;
        7: Result := Sqrt(Rout / RStop) * Power(PDouble(Integer(PVar) - 16)^, -ItResultI);    //Pvar does only work for single formula
      else Result := Sqrt(Rout) / Abs(Deriv1);   //AmBox4D + IFS4D         //  / Intpower?
      end;
      if CalcSIT then CalcSmoothIterations(PIteration3D, 0);
    end;
end;

function doHybridIFS3D(PIteration3D: TPIteration3D): Double;
var
  ItExt: TPIteration3Dext;
  n, count, minIt: Integer;
  minDE, de: Double;
  inside: LongBool;
begin
  ItExt := TPIteration3Dext(Integer(PIteration3D) - 56);
  with ItExt^ do
  begin
    if DoJulia then
      mCopyVec(@J1, @Ju1)
    else
      mCopyVec(@J1, @C1);
    mCopyVec(@x, @C1);
    w := 0;
    bFirstIt := 0;
    ItResultI := 0;
    SmoothItD := 0;
    VaryScale := 1;
    OTrap := d65535;
    Dfree1 := 0;
    minDE := OTrap;
    minIt := 0;
    inside := bIsInsideRender;
    n := iStartFrom;
    count := nHybrid[n] and $7FFFFFFF;
    if count > 0 then
      PVar := fHPVar[n];
    while True do
    begin
      while count <= 0 do
      begin
        Inc(n);
        if n > EndTo then
          n := iRepeatFrom;
        count := nHybrid[n] and $7FFFFFFF;
        if count > 0 then
          PVar := fHPVar[n];
      end;
      fHybrid[n](x, y, z, w, PIteration3D);
      Dec(count);
      if nHybrid[n] < 0 then
        Continue;
      Inc(ItResultI);
      de := Rout / VaryScale;
      if de < minDE then
      begin
        minDE := de;
        minIt := ItResultI;
        Dfree2 := Dfree1;
        if not inside then
        begin
          if de < RStopD then
            Break;
        end;
      end;
      if ItResultI >= maxIt then
        Break;
    end;
    SmoothItD := minIt;
    ItResultI := minIt;
    OTrap := Dfree2;
    Result := minDE;
  end;
end;

function doHybridIFS3DnoVecIni(PIteration3D: TPIteration3D): Double; //to use behind common fractals, use the new vec for it
var
  ItExt: TPIteration3Dext;
  n, count, minIt: Integer;
  minDE, de: Double;
  inside: LongBool;
begin
  ItExt := TPIteration3Dext(Integer(PIteration3D) - 56);
  with ItExt^ do
  begin
    bFirstIt := 0;
    ItResultI := 0;
    SmoothItD := 0;
    VaryScale := 1;
    OTrap := d65535;
    Dfree1 := 0;
    minDE := OTrap;
    minIt := 0;
    inside := bIsInsideRender;
    n := iStartFrom;
    count := nHybrid[n] and $7FFFFFFF;
    if count > 0 then
      PVar := fHPVar[n];
    while True do
    begin
      while count <= 0 do
      begin
        Inc(n);
        if n > EndTo then
          n := iRepeatFrom;
        count := nHybrid[n] and $7FFFFFFF;
        if count > 0 then
          PVar := fHPVar[n];
      end;
      fHybrid[n](x, y, z, w, PIteration3D);
      Dec(count);
      if nHybrid[n] < 0 then
        Continue;
      Inc(ItResultI);
      de := Rout / VaryScale;
      if de < minDE then
      begin
        minDE := de;
        minIt := ItResultI;
        Dfree2 := Dfree1;
        if not inside then
        begin
          if de < RStopD then
            Break;
        end;
      end;
      if ItResultI >= maxIt then
        Break;
    end;
    SmoothItD := minIt;
    ItResultI := minIt;
    OTrap := Dfree2;
    Result := minDE;
  end;
end;     

procedure CalcSmoothIterations(PIt3D: TPIteration3D; n: Integer);
var
  d: Double;
  PItExt: TPIteration3Dext;
begin
    PItExt := TPIteration3Dext(Integer(PIt3D) - 56);
    if PIt3D.Rout <= 1 then
      PIt3D.SmoothItD := PIt3D.ItResultI
    else if PItExt^.Rold < 1 then
      PIt3D.SmoothItD := PIt3D.ItResultI + PIt3D.LNRStop - Ln(0.5 * Ln(PIt3D.Rout)) * PIt3D.fHln[n]
    else
    begin
      d := Ln(0.5 * Ln(PIt3D.Rout));
      PIt3D.SmoothItD := PIt3D.ItResultI + (PIt3D.LNRStop - d) / (d - Ln(0.5 * Ln(PItExt^.Rold)));
    end;
end;

procedure doHybridPas(PIteration3D: TPIteration3D);   //new ext version
var n: Integer;
begin
    with TPIteration3Dext(Integer(PIteration3D) - 56)^ do
    begin
      if DoJulia then mCopyVec(@J1, @JU1) else mCopyVec(@J1, @C1);
      mCopyVec(@x, @C1);
      w     := 0;
      Rout  := x * x + y * y + z * z;
      OTrap := Rout;
      n     := iStartFrom;
      bTmp  := nHybrid[n] and $7FFFFFFF;
      PVar  := fHPVar[n];
      bFirstIt  := 0;
      ItResultI := 0;
      repeat
        Rold := Rout;
        while bTmp <= 0 do
        begin
          Inc(n);
          if n > EndTo then n := iRepeatFrom;
          bTmp := nHybrid[n] and $7FFFFFFF;
          if bTmp > 0 then PVar := fHPVar[n];
        end;
        fHybrid[n](x, y, z, w, PIteration3D);
        Dec(bTmp);
        if nHybrid[n] < 0 then Continue else
        begin
          Inc(ItResultI);
          Rout := x * x + y * y + z * z;
          if Rout < OTrap then OTrap := Rout;
        end;
      until (ItResultI >= maxIt) or (Rout > RStop);
      if CalcSIT then CalcSmoothIterations(PIteration3D, n);
    end;
end;

function doHybrid4DDEPas(PIteration3D: TPIteration3D): Double;
var n: Integer;
begin
    with TPIteration3Dext(Integer(PIteration3D) - 56)^ do
    begin
      Rotate4Dex(@C1, @x, @SMatrix4);
      if DoJulia then
      begin
        mCopyVec(@J1, @JU1);
        J4 := Ju4;
      end
      else
      begin
        mCopyVec(@J1, @x);
        J4 := w;
      end;
      Rout := x*x + y*y + z*z + w*w;
      case (DEoption and $38) of
        16:  Deriv1 := Rout;
        32:  begin Deriv1 := 1; Deriv2 := 0; Deriv3 := 0; end;
      else Deriv1 := 1;
      end;
      OTrap := Rout;
      n     := iStartFrom;
      bTmp  := nHybrid[n] and $7FFFFFFF;
      PVar  := fHPVar[n];
      bFirstIt  := 0;
      ItResultI := 0;
      repeat
        Rold := Rout;
        while bTmp <= 0 do
        begin
          Inc(n);
          if n > EndTo then n := iRepeatFrom;
          bTmp := nHybrid[n] and $7FFFFFFF;
          if bTmp > 0 then PVar := fHPVar[n];
        end;
        fHybrid[n](x, y, z, w, PIteration3D);   //todo: parse 3d DEs deriv1 to w and back
        Dec(bTmp);
        if nHybrid[n] >= 0 then
        begin
          Inc(ItResultI);
          Rout := (x * x + y * y + z * z + w * w);
          if Rout < OTrap then OTrap := Rout;
        end;
      until
        (ItResultI >= maxIt) or (Rout > RStop);
      case DEoption and 7 of
        4: Result := Abs(z) * Ln(Abs(z)) / Deriv1;
        7: Result := Sqrt(Rout / RStop) * Power(PDouble(Integer(PVar) - 16)^, -ItResultI);    //Pvar does only work for single formula
      else Result := Sqrt(Rout) / Abs(Deriv1);   //AmBox4D + IFS4D
      end;
      if CalcSIT then CalcSmoothIterations(PIteration3D, n);
    end;
end;


procedure doHybrid4DPas(PIteration3D: TPIteration3D);    
var n: Integer;
begin
    with TPIteration3Dext(Integer(PIteration3D) - 56)^ do
    begin      //eax, edx, ecx
      Rotate4Dex(@C1, @x, @SMatrix4);
      if DoJulia then
      begin
        mCopyVec(@J1, @JU1);
        J4 := Ju4;
      end
      else
      begin
        mCopyVec(@J1, @x);
       // w := w + dWadd4dstep;  //test: 4d projection, stepping with w add parameter
        J4 := w; 
      end;
      Rout  := x*x + y*y + z*z + w*w;
      OTrap := Rout;
      n     := iStartFrom;
      bTmp  := nHybrid[n] and $7FFFFFFF;
      PVar  := fHPVar[n];
      bFirstIt  := 0;
      ItResultI := 0;
      repeat
        Rold := Rout;
        while bTmp <= 0 do
        begin
          Inc(n);
          if n > EndTo then n := iRepeatFrom;
          bTmp := nHybrid[n] and $7FFFFFFF;
          if bTmp > 0 then PVar := fHPVar[n];
        end;
        fHybrid[n](x, y, z, w, PIteration3D);
        Dec(bTmp);
        if nHybrid[n] >= 0 then
        begin
          Inc(ItResultI);              //test: abs( + + - ); minkowski
          Rout := x * x + y * y + z * z + w * w;
          if Rout < OTrap then OTrap := Rout;
        end;
      until
        (ItResultI >= maxIt) or (Rout > RStop);
      if CalcSIT then CalcSmoothIterations(PIteration3D, n);
    end;
end;

procedure doHybrid4DSSE2(PIteration3D: TPIteration3D);  //new ext version
begin
  doHybrid4DPas(PIteration3D);
end;

function doHybridPasDE(PIteration3D: TPIteration3D): Double; //new ext version
var n: Integer;
begin
    with TPIteration3Dext(Integer(PIteration3D) - 56)^ do
    begin
      if DoJulia then mCopyVec(@J1, @JU1) else mCopyVec(@J1, @C1);
      mCopyVec(@x, @C1);
      Rout  := x * x + y * y + z * z;
      OTrap := Rout;
      n     := iStartFrom;
      btmp  := nHybrid[n] and $7FFFFFFF;
      PVar  := fHPVar[n];
      case (DEoption and $38) of
        16:  w := Rout;
        32:  begin Deriv1 := 1; Deriv2 := 0; Deriv3 := 0; end;
      else w := 1;
      end;
      bFirstIt  := 0;
      ItResultI := 0;
      repeat
        Rold := Rout;
        while btmp <= 0 do
        begin
          Inc(n);
          if n > EndTo then n := iRepeatFrom;
          btmp := nHybrid[n] and $7FFFFFFF;
          PVar := fHPVar[n];
        end;
        fHybrid[n](x, y, z, w, PIteration3D);   //access violation with new formulaclass sometimes
        Dec(btmp);
        if nHybrid[n] >= 0 then
        begin
          Inc(ItResultI);
          Rout := x * x + y * y + z * z;
          if Rout < OTrap then OTrap := Rout;
        end;
      until
        (ItResultI >= maxIt) or (Rout > RStop);

      if (DEoption and $38) = 32 then
        Result := Sqrt(Rout) * 0.5 * Ln(Rout) / Deriv1
      else
      case DEoption and 7 of
        4: Result := Abs(y) * Ln(Abs(y)) / w; //Julia?
        7: Result := Sqrt(Rout / RStop) * Power(PDouble(Integer(PVar) - 16)^, -ItResultI);  //Bulb, not really working
      else Result := Sqrt(Rout) / Abs(w);   //AmBox + IFS
      end;

      if CalcSIT then CalcSmoothIterations(PIteration3D, n);
    end;
end;

procedure doHybridSSE2(PIteration3D: TPIteration3D);  //new ext version
begin
  doHybridPas(PIteration3D);
end;

function doHybridDESSE2(PIteration3D: TPIteration3D): Double; //result in st(0)  new ext version
begin
  Result := doHybridPasDE(PIteration3D);
end;

procedure HybridItTricorn(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var xt, yt, zt: Double;
begin
    with PIteration3D^ do
    begin
      xt := x;
      yt := y;
      zt := z;
      x  := xt * xt - yt * yt - zt * zt + J1;
      y  := 2 * xt * yt + J2;
      z  := PDouble(Integer(PVar) - 16)^ * xt * zt + J3 * PDouble(Integer(PVar) - 24)^;
    end;
end;

{procedure HybridItTricorn(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var xt: Double;
begin
    with PIteration3D^ do
    begin
      xt := x;
      x  := x * x - y * y - z * z + J1;
      y  := 2 * xt * y + J2;
      z  := dOption1 * xt * z + J3;    
    end;
end;}
                                             
procedure HybridQuat(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var xt, yt, zt: Double;
begin
    with PIteration3D^ do
    begin
      xt := x;       //orig
      yt := y;
      zt := z;
      x  := x * x - y * y - z * z - w * w + J1;
      y  := 2 * (y * xt + z * w) + J2;
      z  := 2 * (z * xt + PDouble(Integer(PVar) - 16)^ * yt * w) + J3;
      w  := 2 * (w * xt + yt * zt) + PDouble(Integer(PVar) - 24)^
                                   + PDouble(Integer(PIteration3D) - 56)^;
    end;
end;
            //x:eax,y:edx,z:ecx,w:esp->ebp+12, PIt:ebp+8
procedure HybridQuatSSE2(var x, y, z, w: Double; PIteration3D: TPIteration3D);
begin
    HybridQuat(x, y, z, w, PIteration3D);
end;

procedure HybridItIntPow2(var x, y, z, w: Double; PIteration3D: TPIteration3D); //sine bulb
var
  xt, yt, zt: Double;
  a, a2: Double;
begin
    with PIteration3D^ do
    begin
      xt := x;
      yt := y;
      zt := z;
      a := xt * xt + yt * yt;
      z := 2 * zt * Sqrt(a) * PDouble(Integer(PVar) - 16)^ + J3;
      a2 := (a - zt * zt) / a;
      x := a2 * (xt * xt - yt * yt) + J1;
      y := 2 * a2 * xt * yt + J2;
    end;
end;
            //x:eax,y:edx,z:ecx,w:esp->ebp+12, PIt:ebp+8
procedure HybridItIntPow2SSE2(var x, y, z, w: Double; PIteration3D: TPIteration3D);
begin
    HybridItIntPow2(x, y, z, w, PIteration3D);
end;

procedure HybridFloatPow(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var th, ph, pp: Double;
    Esin1, Ecos1, Esin2, Ecos2: Double;
begin
    with PIteration3D^ do
    begin
      th := ArcTan2(y, x);
      ph := ArcTan2(z, Sqrt(Sqr(x) + Sqr(y)));   //  ArcSin(z / R);
      pp := Power(Rout, 0.5 * PDouble(Integer(PVar) - 16)^);
      SinCosD(PDouble(Integer(PVar) - 16)^ * ph, Esin1, Ecos1);
      SinCosD(PDouble(Integer(PVar) - 16)^ * th, Esin2, Ecos2);
      x := pp * Ecos1 * Ecos2 + J1;
      y := pp * Ecos1 * Esin2 + J2;
      z := PDouble(Integer(PVar) - 24)^ * pp * Esin1 + J3;
    end;
end;

      //x:eax,y:edx,z:ecx,w:esp->ebp+12, PIt:ebp+8
procedure HybridItIntPow3(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var
  sx, sy, sz, R, A: Double;
begin
    with PIteration3D^ do
    begin
      sx := x * x;
      sy := y * y;
      R := sx + sy;
      sz := z * z;
      A := 1 - (3 * sz) / (R + d1em40);
      x := A * x * (sx - 3 * sy) + J1;
      y := A * y * (3 * sx - sy) + J2;
      z := PDouble(Integer(PVar) - 16)^ * z * (3 * R - sz) + J3;
    end;
end;

procedure HybridItIntPow4(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var
  sx, sy, sz, R, A: Double;
begin
    with PIteration3D^ do
    begin
      sx := x * x;
      sy := y * y;
      R  := sx + sy;
      sz := z * z;
      A := 1 + (sz * (sz - 6 * R)) / (R * R + d1em40);
      y := 4 * x * y * A * (sx - sy) + J2;
      z := PDouble(Integer(PVar) - 16)^ * 4 * Sqrt(R) * z * (R - sz) + J3;
      x := A * (sx * (sx - 6 * sy) + sy * sy) + J1;
    end;
end;

procedure HybridIntP5(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var
  sx, sy, sz, A, R: Double;
begin
  with PIteration3D^ do
  begin
    sx := x * x;
    sy := y * y;
    R  := sx + sy;
    sz := z * z;
    A  := 1 + 5 * (sz * sz - 2 * R * sz) / (R * R + d1em40);
    y  := A * y * (5 * sx * sx - sy * (10 * sx - sy)) + J2;
    z  := PDouble(Integer(PVar) - 16)^ * z * (sz * (sz - 10 * R) + 5 * R * R) + J3;
    x  := A * x * (sx * (sx - 10 * sy) + 5 * sy * sy) + J1;
  end;
end;

procedure HybridIntP6(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var
  S1, S2, sz, A, R: Double;
begin
  with PIteration3D^ do
  begin
    S1 := x * x;
    S2 := y * y;
    R  := S1 + S2;
    sz := z * z;
    A  := 1 - (sz * (sz * (sz - 15 * R) + 15 * R * R)) / (R * R * R + d1em40);
    y  := 2 * A * x * y * (S1 * (3 * S1 - 10 * S2) + 3 * S2 * S2) + J2;
    z  := PDouble(Integer(PVar) - 16)^ * 2 * z * Sqrt(R) * (sz * (3 * sz - 10 * R) + 3 * R * R) + J3;
    x  := A * (S1 * S1 * (S1 - 15 * S2) + S2 * S2 * (15 * S1 - S2)) + J1;
  end;
end;

procedure HybridIntP7(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var
  S1, S2, S3, A, R: Double;
begin
  with PIteration3D^ do
  begin
    S1 := x * x;
    S2 := y * y;
    R  := S1 + S2;
    S3 := z * z;
    A  := 1 - 7 * (S3 * (S3 * (S3 - 5 * R) + 3 * R * R)) / (R * R * R + d1em40);
    y  := A * y * (S1 * (S1 * (7 * S1 - 35 * S2) + 21 * S2 * S2) - S2 * S2 * S2) + J2;
    z  := J3 - PDouble(Integer(PVar) - 16)^ * (z * S3 * S3 * S3 - 7 * z * R * (S3 * (3 * S3 - 5 * R) + R * R));
    x  := A * x * (S1 * (S1 * (S1 - 21 * S2) + 35 * S2 * S2) - 7 * S2 * S2 * S2) + J1;
  end;
end;

                       //x:eax,y:edx,z:ecx,w:esp->ebp+12, PIt:ebp+8
procedure HybridIntP8(var x, y, z, w: Double; PIteration3D: TPIteration3D);   //P8 white's formula
var
  xt, yt, zt: Double;
  xx, yy, zz, r, rr, zzzz: Double;
  xxxx, yyyy: Double;
  A: Double;
  termZ, termA: Double;
begin
  with PIteration3D^ do
  begin
    xt := x;
    yt := y;
    zt := z;

    xx := xt * xt;
    yy := yt * yt;
    zz := zt * zt;
    r := xx + yy;
    rr := r * r;
    zzzz := zz * zz;

    termZ := (zzzz - 6 * r * zz + rr);
    termZ := (zz - r) * termZ;
    termZ := Sqrt(r) * termZ;
    z := J3 - 8 * PDouble(Integer(PVar) - 16)^ * zt * termZ;

    termA := zzzz * (70 * rr + zzzz) - 28 * zz * r * (zzzz + rr);
    A := 1 + termA / (rr * rr + d1em40);

    xxxx := xx * xx;
    yyyy := yy * yy;

    y := 8 * xt * yt * A * (xxxx * (xx - 7 * yy) + yyyy * (7 * xx - yy)) + J2;
    x := A * (xxxx * xxxx + yyyy * (70 * xxxx + yyyy) - 28 * xx * yy * (yyyy + xxxx)) + J1;
  end;
end;

                          //x:eax,y:edx,z:ecx,w:esp->ebp+12, PIt:ebp+8
procedure HybridCubeSSE2(var x, y, z, w: Double; PIteration3D: TPIteration3D);  // is used in alt hybrid without DE on w
begin
    HybridCube(x, y, z, w, PIteration3D);
end;

procedure HybridCube(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var
  fold, r, mul: Double;
begin
    with PIteration3D^ do
    begin
      fold := PDouble(Integer(PVar) - 40)^;
      x := Abs(x + fold) - Abs(x - fold) - x;
      y := Abs(y + fold) - Abs(y - fold) - y;
      z := Abs(z + fold) - Abs(z - fold) - z;

      r := x * x + y * y + z * z;
      if r < PDouble(Integer(PVar) - 32)^ then
        mul := PDouble(Integer(PVar) - 24)^
      else if r < 1 then
        mul := PDouble(Integer(PVar) - 16)^ / r
      else
        mul := PDouble(Integer(PVar) - 16)^;

      x := x * mul + J1;
      y := y * mul + J2;
      z := z * mul + J3;
    end;
end;

procedure HybridCubeDE(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var
  fold, r, mul: Double;
begin
    with PIteration3D^ do
    begin
      fold := PDouble(Integer(PVar) - 40)^;
      x := Abs(x + fold) - Abs(x - fold) - x;
      y := Abs(y + fold) - Abs(y - fold) - y;
      z := Abs(z + fold) - Abs(z - fold) - z;

      r := x * x + y * y + z * z;
      if r < PDouble(Integer(PVar) - 32)^ then
        mul := PDouble(Integer(PVar) - 24)^
      else if r < 1 then
        mul := PDouble(Integer(PVar) - 16)^ / r
      else
        mul := PDouble(Integer(PVar) - 16)^;

      w := w * mul;
      x := x * mul + J1;
      y := y * mul + J2;
      z := z * mul + J3;
    end;
end;

procedure HybridCubeSSE2DE(var x, y, z, w: Double; PIteration3D: TPIteration3D);
begin
    HybridCubeDE(x, y, z, w, PIteration3D);
end;

procedure HybridItIntPow2scale(var x, y, z, w: Double; PIteration3D: TPIteration3D); //sine bulb with scaling
var
  s, xs, ys, zs: Double;
  a, a2: Double;
begin
  with PIteration3D^ do
  begin
    s := PDouble(Integer(PVar) - 72)^;
    xs := x / s;
    ys := y / s;
    zs := z / s;

    a := xs * xs + ys * ys;
    z := -2 * zs * Sqrt(a) * s + J3;
    a2 := (a - zs * zs) / a;
    x := (a2 * (xs * xs - ys * ys)) * s + J1;
    y := (2 * a2 * xs * ys) * s + J2;
  end;
end;

procedure HybridSuperCube2(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var R1, R2, m, m2: Double;
    xyzIn, xyzOut: TVec3D;
begin
//    testhybridOptionVals: array[0..5] of Double = (2, 0.5, 1, 1, 2, 1.9);
    if PIteration3D.Rout < PDouble(Integer(PIteration3D.PVar) - 80)^ then     //smooth Bulbox
    with PIteration3D^ do
    begin
      if Rout < PDouble(Integer(PVar) - 88)^ then
        HybridItIntPow2scale(x, y, z, w, PIteration3D)   //ThybridIteration(pCodePointer) := fHIntFunctions[Round(dSIpow)];
      else
      begin
        R1 := PDouble(Integer(PVar) - 88)^;
        m := (Rout - R1) / (PDouble(Integer(PVar) - 80)^ - R1);
        Move(x, xyzIn, 24);
        HybridItIntPow2scale(x, y, z, w, PIteration3D);
        Move(x, xyzOut, 24);
        Move(xyzIn, x, 24);
        fHybridCube(x, y, z, w, PIteration3D);
        R1 := Sqrt(Sqr(x) + Sqr(y) + Sqr(z));
        m2 := 1 - m;
        R2 := R1 * m + m2 * Sqrt(Sqr(xyzOut[0]) + Sqr(xyzOut[1]) + Sqr(xyzOut[2]));
        x := x * m + m2 * xyzOut[0];
        y := y * m + m2 * xyzOut[1];
        z := z * m + m2 * xyzOut[2];
        R1 := R2 / Sqrt(Sqr(x) + Sqr(y) + Sqr(z) + 1e-40);
        x := x * R1;
        y := y * R1;
        z := z * R1;
      end;
    end
    else fHybridCube(x, y, z, w, PIteration3D);

{    if PIteration3D.Rout < PDouble(Integer(PIteration3D.PVar) - 80)^ then     //Bulbox, only RThreshold
      HybridItIntPow2scale(x, y, z, w, PIteration3D)                           //bscale5 vid=34s, 29.6s
    else
      fHybridCube(x, y, z, w, PIteration3D);  }
end;

procedure HybridFolding(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var
  fold: Double;
  fn: ThybridIteration;
begin
  with PIteration3D^ do
  begin
    fold := PDouble(Integer(PVar) - 24)^;
    x := Abs(x + fold) - Abs(x - fold) - x;
    y := Abs(y + fold) - Abs(y - fold) - y;
    z := Abs(z + fold) - Abs(z - fold) - z;

    fn := ThybridIteration(PPointer(Integer(PVar) - 52)^);
    if Assigned(fn) then
      fn(x, y, z, w, PIteration3D);
  end;
end;

procedure EmptyFormula(var x, y, z, w: Double; PIteration3D: TPIteration3D);
begin //not used formulas, itCount might be set to bigger 0 and executed!

end;

//########### from here: custom formulas generation, not at runtime -> use IFStest instead!

procedure HybridCustomIFS;   //for IFS, different calling convention!  esi+edi is @it3dext.x+128 and @Pvar
begin
end;


{  fld1                 1
  fld    X              x,1
  fst    st(2)          x,1,x
  fmul   st(0), st(0)   xx,1,x
  fsubp                 1-xx
  fsqrt
  fpatan}

{  fldln2   power function
  fxch
  fyl2x
  fxch
  fmulp
  fldl2e
  fmulp
  fld    st(0)
  frndint
  fsub   st(1), st(0)
  fxch
  f2xm1
  fld1
  faddp
  fscale
  fstp   st(1)
}
      //x:eax,y:edx,z:ecx,w:esp->ebp+12, PIt:ebp+8

                     //x:eax,y:edx,z:ecx,w:esp->ebp+12, PIt:ebp+8

                           //x:eax,y:edx,z:ecx,w:esp->ebp+12, PIt:ebp+8
procedure AexionC(var x, y, z, w: Double; PIteration3D: TPIteration3D);
var
  ph, th, pp, r1, Sx, Cx, Sy, Cy: Double;
  pb: PByteArray;
  pd: PDouble;
begin
  with TPIteration3Dext(Integer(PIteration3D) - 56)^ do
  begin
    pb := Pointer(Integer(PVar) - 56); // Aexion rotate c [Power, Z mul, Enable RotC, Cond Phi, Power C, Cz mul, Mod]
    pd := @pb[56 - 16];
    r1 := x * x + y * y + z * z;
    th := ArcTan2(Sqrt(x * x + z * z), y) * pd^;
    ph := ArcTan2(z, x) * pd^;
    SinCosD(ph, Sx, Cx);
    SinCosD(th, Sy, Cy);
    r1 := Power(r1, pd^ * 0.5);
    x := Cy * Cx * r1 + J1;
    y := Cy * Sx * r1 + J2;
    z := r1 * Sy * PDouble(@pb[56 - 24])^ + J3;

    if pb[56 - 28] <> 0 then  // rotate c
    begin
      if pb[56 - 52] <> 0 then
      begin
        pp := LengthOfVec(SubtractVectors(TPVec3D(@x), TPVec3D(@J1)^));
        pd := @pp;
      end
      else
        pd := @pb[56 - 40];

      r1 := Sqrt(J1 * J1 + J2 * J2 + J3 * J3);
      if pb[56 - 56] = 1 then
      begin
        th := ArcTan2(Sqrt(Sqr(x - J1) + Sqr(z - J3)), y - J2) * pd^;
        ph := ArcTan2(z - J3, x - J1) * pd^;
      end
      else
      begin
        th := ArcTan2(Sqrt(J1 * J1 + J3 * J3), J2) * pd^;
        ph := ArcTan2(J3, J1) * pd^;
      end;

      if (pb[56 - 32] <> 0) and (x > 0) then
        ph := -ph;

      SinCosD(ph, Sx, Cx);
      SinCosD(th, Sy, Cy);
      J1 := Cy * Cx * r1;
      J2 := Cy * Sx * r1;
      J3 := r1 * Sy * PDouble(@pb[56 - 48])^;
    end;
  end;
end;

end.




