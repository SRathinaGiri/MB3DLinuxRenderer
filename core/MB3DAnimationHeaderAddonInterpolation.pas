unit MB3DAnimationHeaderAddonInterpolation;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses
  MB3DAnimationModel;

procedure InterpolateMB3DAnimationV5HeaderAddon(
  const FromAddon, ToAddon: TMB3DAnimationV5HeaderAddon; const Position: Double;
  out InterpolatedAddon: TMB3DAnimationV5HeaderAddon; out InterpolatedFormulaCount: Integer);

implementation

uses
  Math, SysUtils, TypeDefinitions;

function ClampPosition(const Position: Double): Double;
begin
  Result := Position;
  if Result < 0 then Result := 0;
  if Result > 1 then Result := 1;
end;

function FormulaIdentityMatches(const FirstFormula, SecondFormula: THAformula): Boolean;
begin
  Result := (FirstFormula.iFnr = SecondFormula.iFnr) and
    CompareMem(@FirstFormula.CustomFname[0], @SecondFormula.CustomFname[0],
      SizeOf(FirstFormula.CustomFname));
end;

function InterpolateAngle(const FirstValue, SecondValue, Position: Double): Double;
var
  Delta: Double;
begin
  Delta := SecondValue - FirstValue;
  while Delta > 180 do Delta := Delta - 360;
  while Delta < -180 do Delta := Delta + 360;
  Result := FirstValue + Delta * Position;
end;

procedure InterpolateMB3DAnimationV5HeaderAddon(
  const FromAddon, ToAddon: TMB3DAnimationV5HeaderAddon; const Position: Double;
  out InterpolatedAddon: TMB3DAnimationV5HeaderAddon; out InterpolatedFormulaCount: Integer);
var
  FromRuntime, ToRuntime, ResultRuntime: THeaderCustomAddon;
  T: Double;
  FormulaIndex, OptionIndex, OptionCount: Integer;
  InterpolatedIterations: Single;
begin
  InterpolatedAddon := FromAddon;
  InterpolatedFormulaCount := 0;
  if SizeOf(THeaderCustomAddon) <> MB3DAnimationV5HeaderAddonSize then
    Exit;
  Move(FromAddon, FromRuntime, SizeOf(FromRuntime));
  Move(ToAddon, ToRuntime, SizeOf(ToRuntime));
  ResultRuntime := FromRuntime;
  T := ClampPosition(Position);
  if FromRuntime.bOptions1 <> ToRuntime.bOptions1 then
  begin
    Move(ResultRuntime, InterpolatedAddon, SizeOf(ResultRuntime));
    Exit;
  end;
  for FormulaIndex := 0 to High(ResultRuntime.Formulas) do
    if FormulaIdentityMatches(FromRuntime.Formulas[FormulaIndex],
       ToRuntime.Formulas[FormulaIndex]) and
       (FromRuntime.Formulas[FormulaIndex].iItCount <> 0) and
       (ToRuntime.Formulas[FormulaIndex].iItCount <> 0) then
    begin
      OptionCount := Min(16, Min(FromRuntime.Formulas[FormulaIndex].iOptionCount,
        ToRuntime.Formulas[FormulaIndex].iOptionCount));
      for OptionIndex := 0 to OptionCount - 1 do
        if FromRuntime.Formulas[FormulaIndex].byOptionType[OptionIndex] in [3..6] then
          ResultRuntime.Formulas[FormulaIndex].dOptionValue[OptionIndex] :=
            InterpolateAngle(FromRuntime.Formulas[FormulaIndex].dOptionValue[OptionIndex],
              ToRuntime.Formulas[FormulaIndex].dOptionValue[OptionIndex], T)
        else
          ResultRuntime.Formulas[FormulaIndex].dOptionValue[OptionIndex] :=
            FromRuntime.Formulas[FormulaIndex].dOptionValue[OptionIndex] * (1 - T) +
            ToRuntime.Formulas[FormulaIndex].dOptionValue[OptionIndex] * T;
      if (FromRuntime.bOptions1 and 3) = 1 then
      begin
        InterpolatedIterations := PSingle(@FromRuntime.Formulas[FormulaIndex].iItCount)^ * (1 - T) +
          PSingle(@ToRuntime.Formulas[FormulaIndex].iItCount)^ * T;
        PSingle(@ResultRuntime.Formulas[FormulaIndex].iItCount)^ := InterpolatedIterations;
      end
      else
        ResultRuntime.Formulas[FormulaIndex].iItCount := Round(
          FromRuntime.Formulas[FormulaIndex].iItCount * (1 - T) +
          ToRuntime.Formulas[FormulaIndex].iItCount * T);
      Inc(InterpolatedFormulaCount);
    end;
  Move(ResultRuntime, InterpolatedAddon, SizeOf(ResultRuntime));
end;

end.
