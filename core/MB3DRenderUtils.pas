unit MB3DRenderUtils;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

procedure MinMaxClip15bit(var Value: Single; var Target: Word);

implementation

procedure MinMaxClip15bit(var Value: Single; var Target: Word);
begin
  if Value < 0 then
    Target := 0
  else if Value > 32767 then
    Target := 32767
  else
    Target := Round(Value);
end;

end.
