# Linux headless renderer

The i386 worker now loads native `.m3a` animation frames, executes external
`.m3f` formula code, ray-marches geometry, applies saved palettes, directional
lights, MB3D's 24-bit ambient shadow, gamma, depth/dynamic fog, and
optional formula-ray hard shadows, and writes RGB PNG files without Lazarus
LCL or a display server.

Build from the repository root in Ubuntu/WSL:

```sh
bash scripts/build-linux-worker-i386.sh
```

Fast mono preview using the saved camera and scene parameters:

```sh
./build/linux-i386/mb3d_worker \
  --animation scene.m3a \
  --frame 0 \
  --output jobs/output/preview.png \
  --threads 4 \
  --assets assets \
  --size 640x640 \
  --shadows off \
  --ambient auto \
  --reflection report
```

Final stereo render at the dimensions stored in the M3A:

```sh
./build/linux-i386/mb3d_worker \
  --animation scene.m3a \
  --frame 0 \
  --output jobs/output/frame-000000.png \
  --threads 4 \
  --assets assets \
  --stereo on \
  --hard-shadow post \
  --ambient auto \
  --reflection report
```

Stereo writes `frame-000000-L.png` and `frame-000000-R.png`. The worker uses
the M3A's saved stereo optics but the CLI decides whether stereo is rendered.

`--shadows on` is the default and runs Mandelbulb3D's formula-based hard
shadow rays inline during the geometry pass. `--hard-shadow post` renders the
geometry first and then applies a Windows-style hard-shadow post pass from the
saved z-buffer, which is the better parity target for MB3D's post workflow.
Both modes can be dramatically slower on dense IFS scenes. Shadow rays use a
minimum forward step and a 4,096 step safety ceiling so malformed or near-zero
distance estimates cannot make a worker run forever. Use `--shadows off` or
`--hard-shadow off` for previews.

`--ambient auto` is the default. For MB3D SSAO24 scenes, `auto` keeps the
stable radial 24-bit path that currently gives the closest frame-80 Windows
parity score. Use `--ambient classic24` to force the source-ported Windows
SSAO24 scan, `--ambient radial24` to force the deterministic radial 24-bit
path, or `--ambient off` for diagnostics.

`--reflection report` is the default and reports the saved MB3D
specular-reflection/transmission settings without changing pixels. This keeps
current parity renders reproducible while making reflection omissions visible
in the event log. `--reflection off` suppresses that post step explicitly.
`--reflection post` enables the first headless formula-ray reflection pass:
surface hits are reconstructed from the z-buffer, reflected rays are marched
through the formula DE, and reflected background/formula hits are blended into
the RGB output. Transmission is detected and reported but still needs the full
Windows `CalcSR` vector-color/transmission port.

Current fidelity limits:

- MB3D SSAO24 has both a source-ported classic scan and a deterministic
  radial 24-bit scan. The radial path uses a stable random phase so repeated
  renders are reproducible;
- the other legacy ambient-shadow modes still use the portable horizon pass;
- enabled global directional lights are supported; positional lights and
  light-map lights are reported as unsupported in the shading event;
- saved depth fog and two-color dynamic fog are supported; visible volumetric
  light shapes still need parity validation;
- specular reflection has an initial headless formula-ray post pass, but
  transmission and exact Windows `CalcSR` vector paint parity still need a
  GUI-free port;
- background maps, transparency, and the remaining GUI post-process chain still
  need GUI-free ports.

Run the portable rendering regression tests with:

```sh
bash scripts/test-linux-worker-i386.sh
```

To measure parity, render the same frame and dimensions to PNG in Windows
MB3D and in the Linux worker, then run (Python 3 standard library only):

```sh
python3 scripts/compare-renders.py windows-reference.png linux-render.png
```

The report includes changed-pixel percentage, mean absolute channel error,
RMSE, and maximum channel error. Optional `--max-mae` and
`--max-channel-error` limits make the command suitable for regression tests.
For multi-frame or multi-scene tracking, use `scripts/run-parity-suite.py`
with a local manifest as described in `docs/parity-suite.md`.

The executable has no GUI/display dependency. For a relocatable distribution
that does not require `libc6:i386` to be installed on the target, build the
self-contained archive:

```sh
bash scripts/package-linux-worker-i386.sh
```

This creates `dist/mb3d-worker-linux-i386.tar.gz` and its SHA-256 checksum.
The archive contains the worker, formulas, light maps, and the exact i386
loader, C/thread runtime, and GCC unwinding library used to build it. After
copying it to an x86-64 Linux machine, extract it and run:

```sh
tar -xzf mb3d-worker-linux-i386.tar.gz
./mb3d-worker-linux-i386/run-mb3d-worker --version
```

Render commands use the same CLI, but omit `--assets`: the packaged launcher
automatically selects its bundled assets. The target only needs an x86-64
Linux kernel with 32-bit executable support and `/bin/sh`; it does not need
Free Pascal, Lazarus, 32-bit glibc packages, or a display server.

The development binary in `build/linux-i386` remains dynamically linked to
`libc6:i386`. A conventional single-file static glibc binary is not emitted:
the FPC 3.2.2 i386 startup used here is incompatible with glibc's static-PIE
startup path. The self-contained archive avoids that host-runtime dependency
without changing the proven formula execution path.
