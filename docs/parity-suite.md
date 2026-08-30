# Windows parity suite

Use the parity suite to render Linux headless frames and compare them with PNGs
exported by Windows Mandelbulb3D. It is intended for regression tracking while
porting the remaining Windows paint and post-process paths.

Build the worker first:

```sh
sh scripts/build-linux-worker-i386.sh
```

Create a local manifest from the example and update the paths to the Windows
reference PNGs and `.m3a` inputs available on your machine:

```sh
cp tests/parity-suite.example.json tests/parity-suite.local
```

Run all cases from WSL/Debian:

```sh
python3 scripts/run-parity-suite.py tests/parity-suite.local
```

Run one named case:

```sh
python3 scripts/run-parity-suite.py tests/parity-suite.local \
  --case fractal20260325-frame-0080
```

Each case reports:

- `completionPercent`: `100 * (1 - MAE / 255)`
- `meanAbsoluteChannelError`: average RGB channel error
- `rootMeanSquareChannelError`: RMS RGB channel error
- `maxChannelError`: largest single-channel error

The manifest supports per-case thresholds:

- `maxMae`
- `maxChannelError`
- `minCompletionPercent`

Each case can also set `ambient` to `auto`, `classic24`, `radial24`, or `off`.
Omitting it uses the worker default, `auto`.

Use `hardShadow` with `inline`, `post`, or `off` to select the hard-shadow
path directly. If `hardShadow` is omitted, the older `shadows` field is still
passed as `--shadows on|off`.

Keep machine-specific manifests as `*.local`; they are ignored by git.
