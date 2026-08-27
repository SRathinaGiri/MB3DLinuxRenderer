# Test MB3D Linux Renderer on Windows with WSL

This guide tests the precompiled `v0.3.0` release on a Windows x86-64
computer. It does **not** install Free Pascal, Lazarus, GCC, 32-bit glibc, or
any other development package.

## Why Debian

Debian is the smallest low-friction distribution in the standard WSL catalog
for this test. It is smaller than a typical Ubuntu installation and can be
installed directly with `wsl --install -d Debian`. Alpine can be smaller, but
it is not in the standard catalog on every Windows installation and requires
a separate import procedure.

The renderer is an i386 executable. Use an x86-64 Windows machine and WSL 2,
whose Linux kernel supports 32-bit x86 executables. Windows on ARM is not a
supported test target for this release.

## 1. Install WSL 2 and Debian

Open **PowerShell as Administrator** and run:

```powershell
wsl --install -d Debian
```

Restart Windows if requested. Start Debian from the Start menu, or run:

```powershell
wsl -d Debian
```

On its first launch, Debian asks for a Linux username and password. These do
not need to match the Windows account.

If WSL was already installed, update it and make sure Debian uses WSL 2:

```powershell
wsl --update
wsl --set-default-version 2
wsl --set-version Debian 2
wsl --list --verbose
```

The final command should show `Debian` with version `2`.

## 2. Download and verify the release

Run these commands in normal Windows PowerShell:

```powershell
$release = "https://github.com/SRathinaGiri/MB3DLinuxRenderer/releases/download/v0.3.0"
$archive = "$env:USERPROFILE\Downloads\mb3d-worker-v0.3.0-linux-i386.tar.gz"
$checksum = "$archive.sha256"

curl.exe -L "$release/mb3d-worker-v0.3.0-linux-i386.tar.gz" -o $archive
curl.exe -L "$release/mb3d-worker-v0.3.0-linux-i386.tar.gz.sha256" -o $checksum

$expected = ((Get-Content $checksum) -split '\s+')[0].ToLower()
$actual = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $expected) { throw "Release checksum verification failed" }
"Checksum verified: $actual"
```

Do not continue if checksum verification fails.

## 3. Extract it into Debian

Still in PowerShell, run:

```powershell
wsl -d Debian -- bash -lc "mkdir -p ~/mb3d-test && tar -xzf /mnt/c/Users/$env:USERNAME/Downloads/mb3d-worker-v0.3.0-linux-i386.tar.gz -C ~/mb3d-test"
wsl -d Debian
```

The second command opens the Debian shell. Verify the platform and worker:

```sh
uname -m
cd ~/mb3d-test/mb3d-worker-v0.3.0-linux-i386
./run-mb3d-worker --version
```

Expected output:

```text
x86_64
mb3d-worker 0.3.0 (headless RGB renderer)
```

No `apt install` command is required.

## 4. Copy an M3A test file

From the Debian shell, copy an M3A from the Windows filesystem. Replace the
example username and path with the real Windows path, and retain the quotes
when a directory contains spaces:

```sh
cp "/mnt/c/Users/YOUR_WINDOWS_USERNAME/path/to/scene.m3a" ./scene.m3a
ls -lh ./scene.m3a
```

Alternatively, open this address in Windows File Explorer and copy the M3A
into the release directory:

```text
\\wsl$\Debian\home\YOUR_DEBIAN_USERNAME\mb3d-test\mb3d-worker-v0.3.0-linux-i386
```

M3A v5 input is supported in `v0.3.0`. Direct M3P loading is not implemented
in this release yet.

## 5. Run a small mono smoke test

Use a small image and disable hard shadows so the first test completes
quickly:

```sh
mkdir -p output

./run-mb3d-worker \
  --animation ./scene.m3a \
  --frame 0 \
  --output ./output/smoke.png \
  --threads 2 \
  --size 32x32 \
  --stereo off \
  --shadows off
```

A successful run ends with a `MB3D_EVENT` whose type is `complete`. Confirm
that the PNG exists and starts with the standard PNG signature:

```sh
ls -lh ./output/smoke.png
od -An -tx1 -N8 ./output/smoke.png
```

Expected signature:

```text
89 50 4e 47 0d 0a 1a 0a
```

Open the output directory in Windows Explorer:

```sh
explorer.exe "$(wslpath -w "$PWD/output")"
```

## 6. Run a small stereo test

```sh
./run-mb3d-worker \
  --animation ./scene.m3a \
  --frame 0 \
  --output ./output/stereo.png \
  --threads 2 \
  --size 32x32 \
  --stereo on \
  --shadows off

ls -lh ./output/stereo-L.png ./output/stereo-R.png
cmp -s ./output/stereo-L.png ./output/stereo-R.png \
  && echo "WARNING: stereo files are identical" \
  || echo "Stereo outputs are distinct"
```

The renderer uses the saved screen distance and other stereo optics from the
selected M3A keyframe. `--stereo on` decides that both eyes are rendered.

## 7. Run a full-size frame

Remove `--size 32x32` to use the dimensions saved in the M3A. Hard shadows are
enabled by default, but can be very slow on dense scenes:

```sh
./run-mb3d-worker \
  --animation ./scene.m3a \
  --frame 0 \
  --output ./output/final.png \
  --threads 4 \
  --stereo off \
  --shadows on
```

For a faster full-size preview, use `--shadows off`.

## Troubleshooting

### `No such file or directory`

Include `./` before the launcher and run it from the extracted directory:

```sh
cd ~/mb3d-test/mb3d-worker-v0.3.0-linux-i386
./run-mb3d-worker --version
```

The incorrect form `.run-mb3d-worker` does not refer to the current directory.

### `Permission denied`

The archive preserves executable permissions when extracted inside Debian.
If they were lost because the files were extracted on a Windows-mounted
directory, move the archive into the Linux home directory and extract it
again. As a temporary repair:

```sh
chmod +x ./run-mb3d-worker ./mb3d_worker ./runtime/ld-linux.so.2
```

### `Exec format error` or the version command exits immediately

Return to Windows PowerShell and verify WSL 2:

```powershell
wsl --set-version Debian 2
wsl --list --verbose
```

Inside Debian, `uname -m` must report `x86_64`. Windows on ARM is not supported
by this i386 release.

### Missing formula or asset error

Use `./run-mb3d-worker`, which automatically selects the bundled `assets`
directory. Calling `./mb3d_worker` directly does not configure that path.

### Render appears to stop during hard shadows

Hard-shadow formula rays are much slower than the geometry pass for some
scenes. Repeat the smoke test with `--shadows off` before diagnosing a hang.
