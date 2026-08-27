unit MB3DHeadlessAmbientShadow;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses TypeDefinitions;

function ApplyHeadlessAmbientShadow(const Header: TMandHeader10;
  var Samples: array of TsiLight5; out ShadowedPixels: Integer;
  out MeanOcclusion: Single): Boolean;

implementation

uses Math;

const
  DirectionCount = 8;
  RadiusCount = 7;
  DirectionX: array[0..DirectionCount - 1] of ShortInt =
    (1, 1, 0, -1, -1, -1, 0, 1);
  DirectionY: array[0..DirectionCount - 1] of ShortInt =
    (0, 1, 1, 1, 0, -1, -1, -1);
  Radius: array[0..RadiusCount - 1] of Integer = (1, 2, 4, 8, 16, 32, 64);

function ApplyHeadlessAmbientShadow(const Header: TMandHeader10;
  var Samples: array of TsiLight5; out ShadowedPixels: Integer;
  out MeanOcclusion: Single): Boolean;
var X, Y, Direction, RadiusIndex, SampleIndex, NeighbourIndex: Integer;
    NX, NY, DepthDifference, ValidDirections: Integer;
    DirectionOcclusion, Occlusion, TotalOcclusion, Distance,
    DepthScale, Threshold: Single;
begin
  Result := False;
  ShadowedPixels := 0;
  MeanOcclusion := 0;
  if (Header.Width < 1) or (Header.Height < 1) or
    (Length(Samples) <> Header.Width * Header.Height) then Exit;

  { MB3D's GUI ambient-shadow implementations depend on Forms and Windows
    messages.  This portable pass preserves the same buffer contract:
    AmbShadow=0 is unoccluded and AmbShadow=16383 is fully occluded. }
  Threshold := Max(0.01, Abs(Header.sAmbShadowThreshold));
  DepthScale := Threshold * 6;
  TotalOcclusion := 0;
  for Y := 0 to Header.Height - 1 do
    for X := 0 to Header.Width - 1 do
    begin
      SampleIndex := Y * Header.Width + X;
      if Samples[SampleIndex].Zpos >= 32768 then
      begin
        Samples[SampleIndex].AmbShadow := 0;
        Continue;
      end;
      Occlusion := 0;
      ValidDirections := 0;
      for Direction := 0 to DirectionCount - 1 do
      begin
        DirectionOcclusion := 0;
        for RadiusIndex := 0 to RadiusCount - 1 do
        begin
          NX := X + DirectionX[Direction] * Radius[RadiusIndex];
          NY := Y + DirectionY[Direction] * Radius[RadiusIndex];
          if (NX < 0) or (NX >= Header.Width) or
            (NY < 0) or (NY >= Header.Height) then Continue;
          NeighbourIndex := NY * Header.Width + NX;
          if Samples[NeighbourIndex].Zpos >= 32768 then Continue;
          DepthDifference := Integer(Samples[NeighbourIndex].Zpos) -
            Integer(Samples[SampleIndex].Zpos);
          if DepthDifference <= 0 then Continue;
          Distance := Radius[RadiusIndex];
          if (Direction and 1) <> 0 then Distance := Distance * 1.41421356;
          DirectionOcclusion := Max(DirectionOcclusion,
            DepthDifference / (DepthDifference + Distance * DepthScale));
        end;
        Occlusion := Occlusion + DirectionOcclusion;
        Inc(ValidDirections);
      end;
      if ValidDirections > 0 then Occlusion := Occlusion / ValidDirections;
      Occlusion := Sqrt(Max(0, Min(1, Occlusion)));
      Samples[SampleIndex].AmbShadow := Round(Occlusion * 16383);
      if Samples[SampleIndex].AmbShadow > 0 then Inc(ShadowedPixels);
      TotalOcclusion := TotalOcclusion + Occlusion;
    end;
  if Length(Samples) > 0 then MeanOcclusion := TotalOcclusion / Length(Samples);
  Result := True;
end;

end.
