unit MB3DAnimationModel;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

uses
  Classes, SysUtils;

const
  MB3DAnimationV5HeaderSize = 840;
  MB3DAnimationV5HeaderAddonSize = 1136;

type
  TMB3DAnimationV5Header = packed array[0..MB3DAnimationV5HeaderSize - 1] of Byte;
  TMB3DAnimationV5HeaderAddon = packed array[0..MB3DAnimationV5HeaderAddonSize - 1] of Byte;

  TMB3DAnimationKeyFrame = record
    FrameCount: Integer;
    RenderTime: Integer;
    Smoothing: Integer;
    HeaderBytes: TMB3DAnimationV5Header;
    HeaderAddonBytes: TMB3DAnimationV5HeaderAddon;
  end;

  TMB3DAnimationKeyFrames = array of TMB3DAnimationKeyFrame;

  TMB3DAnimationModel = class
  private
    FWidth: Integer;
    FHeight: Integer;
    FScale: Integer;
    FCalc3D: LongBool;
    FInterpolationType: Integer;
    FLooped: Boolean;
    FStereo: Boolean;
    FLeftEyeOnly: Boolean;
    FOutputFormat: Integer;
    FOutputFolder: string;
    FKeyFrames: TMB3DAnimationKeyFrames;
  public
    procedure Clear;
    function LoadFromFile(const FileName: string; out ErrorText: string): Boolean;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property Scale: Integer read FScale;
    property Calc3D: LongBool read FCalc3D;
    property InterpolationType: Integer read FInterpolationType;
    property Looped: Boolean read FLooped;
    property Stereo: Boolean read FStereo;
    property LeftEyeOnly: Boolean read FLeftEyeOnly;
    property OutputFormat: Integer read FOutputFormat;
    property OutputFolder: string read FOutputFolder;
    function KeyFrameCount: Integer;
    function TryLocateFrame(const FrameNumber: Integer; out KeyFrameIndex,
      SubFrame: Integer; out ErrorText: string): Boolean;
    property KeyFrames: TMB3DAnimationKeyFrames read FKeyFrames;
  end;

implementation

procedure TMB3DAnimationModel.Clear;
begin
  FWidth := 0;
  FHeight := 0;
  FScale := 0;
  FCalc3D := False;
  FInterpolationType := 0;
  FLooped := False;
  FStereo := False;
  FLeftEyeOnly := False;
  FOutputFormat := 0;
  FOutputFolder := '';
  SetLength(FKeyFrames, 0);
end;

function TMB3DAnimationModel.KeyFrameCount: Integer;
begin
  Result := Length(FKeyFrames);
end;

function TMB3DAnimationModel.TryLocateFrame(const FrameNumber: Integer;
  out KeyFrameIndex, SubFrame: Integer; out ErrorText: string): Boolean;
var
  FrameOffset, FrameTotal, Index, Duration: Integer;
begin
  Result := False;
  KeyFrameIndex := -1;
  SubFrame := -1;
  ErrorText := '';
  if FrameNumber < 0 then
  begin
    ErrorText := 'Frame number must not be negative';
    Exit;
  end;
  FrameTotal := 0;
  for Index := 0 to High(FKeyFrames) do
    if FKeyFrames[Index].FrameCount > 0 then
      Inc(FrameTotal, FKeyFrames[Index].FrameCount);
  if FrameTotal = 0 then
  begin
    ErrorText := 'Animation contains no renderable frames';
    Exit;
  end;
  FrameOffset := FrameNumber;
  if FLooped then
    FrameOffset := FrameOffset mod FrameTotal
  else if FrameOffset >= FrameTotal then
  begin
    ErrorText := Format('Frame %d is outside the animation range 0..%d',
      [FrameNumber, FrameTotal - 1]);
    Exit;
  end;
  for Index := 0 to High(FKeyFrames) do
  begin
    Duration := FKeyFrames[Index].FrameCount;
    if Duration < 0 then
      Duration := 0;
    if FrameOffset < Duration then
    begin
      KeyFrameIndex := Index;
      SubFrame := FrameOffset;
      Result := True;
      Exit;
    end;
    Dec(FrameOffset, Duration);
  end;
  ErrorText := 'Unable to resolve requested animation frame';
end;

function TMB3DAnimationModel.LoadFromFile(const FileName: string;
  out ErrorText: string): Boolean;
var
  Stream: TFileStream;
  Version, Options, FrameCount, FrameIndex: Integer;
  PreviewWidth, PreviewHeight: Integer;
  PreviewBytes: Int64;
  OutputFolderBytes: array[0..255] of Byte;
begin
  Result := False;
  ErrorText := '';
  Clear;
  if not FileExists(FileName) then
  begin
    ErrorText := 'Animation file not found: ' + FileName;
    Exit;
  end;
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      Stream.ReadBuffer(Version, SizeOf(Version));
      if Version <> 5 then
        raise EStreamError.CreateFmt('Unsupported animation version %d; only v5 is currently supported', [Version]);
      Stream.ReadBuffer(FWidth, SizeOf(FWidth));
      Stream.ReadBuffer(FHeight, SizeOf(FHeight));
      Stream.ReadBuffer(FScale, SizeOf(FScale));
      Stream.ReadBuffer(FCalc3D, SizeOf(FCalc3D));
      Stream.ReadBuffer(OutputFolderBytes, SizeOf(OutputFolderBytes));
      FOutputFolder := PShortString(@OutputFolderBytes)^;
      Stream.ReadBuffer(Options, SizeOf(Options));
      FInterpolationType := Options and 3;
      FLooped := (Options and 4) <> 0;
      FOutputFormat := (Options shr 3) and 7;
      FStereo := (Options and 64) <> 0;
      FLeftEyeOnly := (Options and 128) <> 0;
      Stream.ReadBuffer(FrameCount, SizeOf(FrameCount));
      if (FrameCount < 1) or (FrameCount > 4095) then
        raise EStreamError.CreateFmt('Invalid keyframe count: %d', [FrameCount]);
      SetLength(FKeyFrames, FrameCount);
      for FrameIndex := 0 to High(FKeyFrames) do
      begin
        Stream.ReadBuffer(FKeyFrames[FrameIndex].FrameCount, SizeOf(Integer));
        Stream.ReadBuffer(FKeyFrames[FrameIndex].RenderTime, SizeOf(Integer));
        Stream.ReadBuffer(FKeyFrames[FrameIndex].Smoothing, SizeOf(Integer));
        Stream.ReadBuffer(FKeyFrames[FrameIndex].HeaderBytes, SizeOf(TMB3DAnimationV5Header));
        Stream.ReadBuffer(FKeyFrames[FrameIndex].HeaderAddonBytes, SizeOf(TMB3DAnimationV5HeaderAddon));
      end;
      for FrameIndex := 0 to High(FKeyFrames) do
      begin
        Stream.ReadBuffer(PreviewWidth, SizeOf(PreviewWidth));
        Stream.ReadBuffer(PreviewHeight, SizeOf(PreviewHeight));
        if (PreviewWidth < 0) or (PreviewHeight < 0) then
          raise EStreamError.Create('Invalid preview image size');
        PreviewBytes := Int64(PreviewWidth) * PreviewHeight * SizeOf(Cardinal);
        if (PreviewBytes > Stream.Size - Stream.Position) then
          raise EStreamError.Create('Truncated preview image data');
        Stream.Position := Stream.Position + PreviewBytes;
      end;
      Result := True;
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
    begin
      Clear;
      ErrorText := E.Message;
    end;
  end;
end;

end.
