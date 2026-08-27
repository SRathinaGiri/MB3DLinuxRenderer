unit MB3DExecutableMemory;

{$IFDEF FPC}{$MODE Delphi}{$H+}{$ENDIF}

interface

function AllocateMB3DExecutableMemory(const ByteCount: SizeUInt): Pointer;
procedure FreeMB3DExecutableMemory(const Memory: Pointer; const ByteCount: SizeUInt);

implementation

{$IFDEF WINDOWS}
uses
  Windows;

function AllocateMB3DExecutableMemory(const ByteCount: SizeUInt): Pointer;
begin
  Result := VirtualAlloc(nil, ByteCount, MEM_RESERVE or MEM_COMMIT,
    PAGE_EXECUTE_READWRITE);
end;

procedure FreeMB3DExecutableMemory(const Memory: Pointer; const ByteCount: SizeUInt);
begin
  if Memory <> nil then
    VirtualFree(Memory, 0, MEM_RELEASE);
end;
{$ELSE}
uses
  BaseUnix;

function AllocateMB3DExecutableMemory(const ByteCount: SizeUInt): Pointer;
begin
  Result := fpMMap(nil, ByteCount, PROT_READ or PROT_WRITE or PROT_EXEC,
    MAP_PRIVATE or MAP_ANONYMOUS, -1, 0);
  if Result = Pointer(-1) then
    Result := nil;
end;

procedure FreeMB3DExecutableMemory(const Memory: Pointer; const ByteCount: SizeUInt);
begin
  if Memory <> nil then
    fpMUnMap(Memory, ByteCount);
end;
{$ENDIF}

end.
