#!/usr/bin/env python3
"""Render and compare MB3D Windows/Linux parity fixtures."""

import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path


def load_compare_module():
    path = Path(__file__).with_name("compare-renders.py")
    spec = importlib.util.spec_from_file_location("compare_renders", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def compare_pngs(compare_module, reference, rendered):
    width_a, height_a, pixels_a = compare_module.load_png(reference)
    width_b, height_b, pixels_b = compare_module.load_png(rendered)
    if (width_a, height_a) != (width_b, height_b):
        raise ValueError(
            f"dimension mismatch: {width_a}x{height_a} versus {width_b}x{height_b}"
        )
    errors = [abs(a - b) for a, b in zip(pixels_a, pixels_b)]
    changed_pixels = sum(
        1
        for index in range(0, len(errors), 3)
        if any(errors[index : index + 3])
    )
    mae = sum(errors) / len(errors) if errors else 0.0
    rmse = (sum(error * error for error in errors) / len(errors)) ** 0.5 if errors else 0.0
    return {
        "width": width_a,
        "height": height_a,
        "pixels": width_a * height_a,
        "changedPixels": changed_pixels,
        "changedPercent": changed_pixels * 100 / (width_a * height_a),
        "meanAbsoluteChannelError": mae,
        "rootMeanSquareChannelError": rmse,
        "maxChannelError": max(errors, default=0),
        "completionPercent": max(0.0, (1.0 - mae / 255.0) * 100.0),
    }


def path_from_case(value, base_dir):
    path = Path(value).expanduser()
    if path.is_absolute():
        return path
    return (base_dir / path).resolve()


def render_case(case, manifest_dir, worker, default_assets, out_dir, dry_run):
    name = case["name"]
    output = path_from_case(case.get("output", f"{name}.png"), out_dir)
    output.parent.mkdir(parents=True, exist_ok=True)
    command = [
        str(worker),
        "--animation",
        str(path_from_case(case["animation"], manifest_dir)),
        "--frame",
        str(case["frame"]),
        "--output",
        str(output),
        "--stereo",
        str(case.get("stereo", "off")),
        "--shadows",
        str(case.get("shadows", "off")),
    ]
    assets = case.get("assets", default_assets)
    if assets:
        command.extend(["--assets", str(path_from_case(assets, manifest_dir))])
    if "threads" in case:
        command.extend(["--threads", str(case["threads"])])
    if "size" in case:
        command.extend(["--size", str(case["size"])])
    print(f"[render] {name}")
    print(" ".join(command))
    if not dry_run:
        subprocess.run(command, check=True)
    return output


def check_thresholds(case, metrics):
    failures = []
    if "maxMae" in case and metrics["meanAbsoluteChannelError"] > case["maxMae"]:
        failures.append(
            f"MAE {metrics['meanAbsoluteChannelError']:.6f} > {case['maxMae']}"
        )
    if (
        "maxChannelError" in case
        and metrics["maxChannelError"] > case["maxChannelError"]
    ):
        failures.append(
            f"max channel error {metrics['maxChannelError']} > {case['maxChannelError']}"
        )
    if (
        "minCompletionPercent" in case
        and metrics["completionPercent"] < case["minCompletionPercent"]
    ):
        failures.append(
            "completion "
            f"{metrics['completionPercent']:.3f}% < {case['minCompletionPercent']}%"
        )
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", help="JSON manifest containing parity cases")
    parser.add_argument(
        "--worker",
        default="./build/linux-i386/mb3d_worker",
        help="path to the Linux headless worker",
    )
    parser.add_argument("--assets", default="./assets", help="default asset directory")
    parser.add_argument("--out-dir", default="./jobs/parity", help="render output dir")
    parser.add_argument("--case", action="append", dest="case_names")
    parser.add_argument("--keep-going", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    manifest_path = Path(args.manifest).expanduser().resolve()
    manifest_dir = manifest_path.parent
    with open(manifest_path, "r", encoding="utf-8") as stream:
        manifest = json.load(stream)
    cases = manifest.get("cases", [])
    if args.case_names:
        selected = set(args.case_names)
        cases = [case for case in cases if case.get("name") in selected]
    if not cases:
        raise ValueError("manifest contains no selected cases")

    worker = Path(args.worker).expanduser().resolve()
    out_dir = Path(args.out_dir).expanduser().resolve()
    default_assets = manifest.get("assets", args.assets)
    compare_module = load_compare_module()
    results = []
    failed = False

    for case in cases:
        try:
            output = render_case(
                case, manifest_dir, worker, default_assets, out_dir, args.dry_run
            )
            if args.dry_run:
                continue
            reference = path_from_case(case["reference"], manifest_dir)
            metrics = compare_pngs(compare_module, reference, output)
            failures = check_thresholds(case, metrics)
            result = {
                "name": case["name"],
                "reference": str(reference),
                "rendered": str(output),
                **metrics,
                "passed": not failures,
                "failures": failures,
            }
            results.append(result)
            status = "PASS" if result["passed"] else "FAIL"
            print(
                f"[{status}] {case['name']} "
                f"completion={metrics['completionPercent']:.3f}% "
                f"MAE={metrics['meanAbsoluteChannelError']:.6f} "
                f"RMSE={metrics['rootMeanSquareChannelError']:.6f} "
                f"max={metrics['maxChannelError']}"
            )
            if failures:
                failed = True
                for failure in failures:
                    print(f"  {failure}")
                if not args.keep_going:
                    break
        except (OSError, ValueError, subprocess.CalledProcessError) as error:
            failed = True
            print(f"[ERROR] {case.get('name', '<unnamed>')}: {error}", file=sys.stderr)
            if not args.keep_going:
                break

    if results and not args.dry_run:
        print(json.dumps({"results": results}, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
