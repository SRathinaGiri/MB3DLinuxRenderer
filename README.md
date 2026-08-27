# MB3D Linux Renderer

Headless command-line renderer for Mandelbulb3D scenes on Linux. It has no
Lazarus LCL, Windows API, desktop, or display-server dependency.

The renderer loads an M3A animation, interpolates its saved keyframe and
stereo parameters, executes portable external M3F formulas, renders mono or
stereo frames, and writes RGB PNG files.

> M3A v5 animation input is implemented. M3P parameter-file input is part of
> the repository's intended input surface but is not parsed by the worker yet.

## Repository layout

- `headless/` — CLI worker entry point
- `core/` — GUI-free animation, formula, rendering, shading, and PNG units
- root Pascal units — required Mandelbulb3D math and ray-marching kernel
- `assets/formulas/` — portable compiled M3F formula library
- `assets/lightmaps/` — runtime light-map library
- `scripts/` — Linux build, launcher, and self-contained packaging scripts
- `docs/` — renderer usage and current fidelity notes

## Build on Linux or WSL

The current external M3F execution path requires an i386 Free Pascal build:

```sh
bash scripts/build-linux-worker-i386.sh
```

The development executable is written to `build/linux-i386/mb3d_worker`.

## Render

```sh
./build/linux-i386/mb3d_worker \
  --animation scene.m3a \
  --frame 0 \
  --output frame-000000.png \
  --threads 4 \
  --assets assets \
  --stereo off \
  --shadows off
```

Use `--stereo on` to render separate `-L.png` and `-R.png` images. The CLI
selects mono or stereo rendering; saved screen distance and other stereo
optics come from the selected M3A keyframe.

## Self-contained distribution

```sh
bash scripts/package-linux-worker-i386.sh
```

This creates `dist/mb3d-worker-linux-i386.tar.gz`. The archive bundles the
worker, formulas, light maps, and its exact i386 runtime libraries. A target
x86-64 Linux machine needs 32-bit executable support and `/bin/sh`, but does
not need Lazarus, Free Pascal, 32-bit glibc packages, or a display server.

See [docs/headless-renderer.md](docs/headless-renderer.md) for the complete CLI
examples and current rendering-fidelity limits.

For a compiler-free test on Windows, follow
[docs/testing-on-windows-wsl.md](docs/testing-on-windows-wsl.md).

## License

The port retains the Mandelbulb3D source license in [License.txt](License.txt).
