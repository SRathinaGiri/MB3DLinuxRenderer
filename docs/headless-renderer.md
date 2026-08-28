# Linux headless renderer

The i386 worker now loads native `.m3a` animation frames, executes external
`.m3f` formula code, ray-marches geometry, applies saved palettes, directional
lights, MB3D's 24-bit radial ambient shadow, gamma, depth/dynamic fog, and
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
  --shadows off
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
  --shadows on
```

Stereo writes `frame-000000-L.png` and `frame-000000-R.png`. The worker uses
the M3A's saved stereo optics but the CLI decides whether stereo is rendered.

`--shadows on` is the default and runs Mandelbulb3D's formula-based hard
shadow rays for lights selected in the saved header. This can be dramatically
slower on dense IFS scenes. Shadow rays use a minimum forward step and a 4,096
step safety ceiling so malformed or near-zero distance estimates cannot make
a worker run forever. Use `--shadows off` for previews.

Current fidelity limits:

- randomized 24-bit radial SSAO (MB3D ambient-shadow mode 4) uses the original
  32-direction multiscale kernel and `SSAORcount` accumulation. The headless
  worker uses a stable random phase so repeated renders are reproducible;
- the other legacy ambient-shadow modes still use the portable horizon pass;
- enabled global directional lights are supported; positional lights and
  light-map lights are reported as unsupported in the shading event;
- saved depth fog and two-color dynamic fog are supported; visible volumetric
  light shapes still need parity validation;
- specular reflection, background maps, transparency, and the remaining GUI
  post-process chain still need GUI-free ports.

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
