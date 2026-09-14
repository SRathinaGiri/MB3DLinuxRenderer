# Windows Parity Continuation Report

Last updated: 2026-09-14

## Current branch

- Repository: `SRathinaGiri/MB3DLinuxRenderer`
- Branch: `fix/windows-paint-parity-0.4.0`
- Latest pushed commit at handoff: `7e43b2c Accumulate reflected light with specular vectors`

## Already done

- Published 0.4.0 release workflow work was completed earlier on this branch.
- Worker frame numbering now matches Windows MB3D exported frame names:
  - `--frame 1` renders Windows frame `000001`.
  - `--frame 40` renders Windows frame `000040`.
  - `--frame 80` renders Windows frame `000080`.
  - Internally the animation model remains zero-based.
- Animation interpolation was fixed so later frames no longer render as the same first frame.
- Stereo on/off was verified manually.
- Ambient shadow work was ported enough for current headless parity testing:
  - classic MB3D SSAO24 path exists;
  - deterministic radial 24-bit mode exists;
  - ambient can be forced with `--ambient classic24`, `--ambient radial24`, or disabled with `--ambient off`.
- Hard shadow work has a selectable post formula-ray mode.
- Reflection work now has a real first vector-accumulation pass:
  - saved reflection settings are detected and reported;
  - `--reflection post` reconstructs surface positions, marches reflected formula rays, and accumulates reflected light using specular vectors;
  - saved reflection recursion depth is honored;
  - color-cycling specular lookup was fixed for reflection.

## Current reflection parity fixture

Fixture folder:

`C:\Users\acer\OneDrive\MyProjects\Pascal\MB3DLinuxRender\parity-fixtures\reflection`

Files:

- `ReflectionOnlySample.m3a`
- `ReflectionOnlySample000001.png`
- `ReflectionOnlySample000040.png`
- `ReflectionOnlySample000080.png`

Local ignored manifest updated for this fixture:

`tests/parity-suite.local`

## Latest measured reflection result

Command shape:

```sh
./build/linux-i386/mb3d_worker \
  --animation /mnt/c/Users/acer/OneDrive/MyProjects/Pascal/MB3DLinuxRender/parity-fixtures/reflection/ReflectionOnlySample.m3a \
  --frame 80 \
  --output jobs/parity/reflection-only/ReflectionOnlySample000080-vector2-linux.png \
  --threads 4 \
  --assets assets \
  --hard-shadow off \
  --ambient off \
  --reflection post
```

Frame 80 comparison against Windows reference:

- Before vector accumulation: MAE `44.421`
- After `7e43b2c`: MAE `36.287`
- Reflected pixels: `262144`

This is a meaningful improvement, but not final Windows parity.

## To be done next

- Port the remaining Windows `PaintThread.CalcPixelColorSvec` behavior into the headless reflection path:
  - `CalcTotalLight1`;
  - `CalcTotalLight2`;
  - visible positional light handling;
  - exact background/depth/dynamic fog contribution as used by reflected rays.
- Tighten the `CalcSR.CalcRay` port:
  - exact open-air/background projection;
  - exact `ZZplus`, start-step, and cut-plane behavior;
  - exact recursive absorption scaling.
- Port or explicitly defer transmission:
  - `bCalcTrans`;
  - refraction index handling;
  - absorption/scattering through transparent material.
- Run the three-frame reflection fixture after each major step:
  - frame `1`;
  - frame `40`;
  - frame `80`.
- Only once reflection parity is acceptable, update the release artifact and create the next GitHub release/package.

## Useful commands

Build:

```sh
wsl -d Debian -- bash -lc 'cd /mnt/c/Users/acer/OneDrive/MyProjects/Pascal/MB3DLinuxRender/MB3DLinuxRenderer-release-check && bash scripts/build-linux-worker-i386.sh'
```

Test:

```sh
wsl -d Debian -- bash -lc 'cd /mnt/c/Users/acer/OneDrive/MyProjects/Pascal/MB3DLinuxRender/MB3DLinuxRenderer-release-check && bash scripts/test-linux-worker-i386.sh'
```

Run local parity suite:

```sh
wsl -d Debian -- bash -lc 'cd /mnt/c/Users/acer/OneDrive/MyProjects/Pascal/MB3DLinuxRender/MB3DLinuxRenderer-release-check && python3 scripts/run-parity-suite.py tests/parity-suite.local --keep-going'
```

Reflection debug event:

```sh
MB3D_DEBUG_REFLECTION=1 ./build/linux-i386/mb3d_worker ...
```

This prints a `reflection-debug` event with candidate pixel count and max specular absorption.
