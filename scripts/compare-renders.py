#!/usr/bin/env python3
"""Compare two 8-bit RGB/RGBA, non-interlaced PNG renders without Pillow."""

import argparse
import json
import struct
import sys
import zlib


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def load_png(path):
    with open(path, "rb") as stream:
        data = stream.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: not a PNG")
    position = 8
    compressed = bytearray()
    width = height = color_type = None
    while position < len(data):
        length = struct.unpack(">I", data[position : position + 4])[0]
        kind = data[position + 4 : position + 8]
        payload = data[position + 8 : position + 8 + length]
        position += 12 + length
        if kind == b"IHDR":
            width, height, depth, color_type, compression, filtering, interlace = (
                struct.unpack(">IIBBBBB", payload)
            )
            if depth != 8 or color_type not in (2, 6) or interlace != 0:
                raise ValueError(
                    f"{path}: only 8-bit RGB/RGBA non-interlaced PNG is supported"
                )
            if compression != 0 or filtering != 0:
                raise ValueError(f"{path}: unsupported PNG compression/filter method")
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break
    channels = 3 if color_type == 2 else 4
    stride = width * channels
    raw = zlib.decompress(compressed)
    expected = height * (stride + 1)
    if len(raw) != expected:
        raise ValueError(f"{path}: unexpected decompressed size")
    rows = []
    previous = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        source = raw[offset + 1 : offset + 1 + stride]
        offset += stride + 1
        row = bytearray(stride)
        for x, value in enumerate(source):
            left = row[x - channels] if x >= channels else 0
            up = previous[x]
            upper_left = previous[x - channels] if x >= channels else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = up
            elif filter_type == 3:
                predictor = (left + up) // 2
            elif filter_type == 4:
                predictor = paeth(left, up, upper_left)
            else:
                raise ValueError(f"{path}: unknown PNG filter {filter_type}")
            row[x] = (value + predictor) & 255
        rows.append(bytes(row))
        previous = row
    rgb = bytearray(width * height * 3)
    target = 0
    for row in rows:
        for source in range(0, len(row), channels):
            rgb[target : target + 3] = row[source : source + 3]
            target += 3
    return width, height, bytes(rgb)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("windows_png")
    parser.add_argument("linux_png")
    parser.add_argument("--max-mae", type=float)
    parser.add_argument("--max-channel-error", type=int)
    args = parser.parse_args()
    width_a, height_a, pixels_a = load_png(args.windows_png)
    width_b, height_b, pixels_b = load_png(args.linux_png)
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
    result = {
        "width": width_a,
        "height": height_a,
        "pixels": width_a * height_a,
        "changedPixels": changed_pixels,
        "changedPercent": changed_pixels * 100 / (width_a * height_a),
        "meanAbsoluteChannelError": mae,
        "rootMeanSquareChannelError": rmse,
        "maxChannelError": max(errors, default=0),
    }
    print(json.dumps(result, indent=2))
    failed = (args.max_mae is not None and mae > args.max_mae) or (
        args.max_channel_error is not None
        and result["maxChannelError"] > args.max_channel_error
    )
    return 1 if failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, zlib.error) as error:
        print(f"compare-renders: {error}", file=sys.stderr)
        sys.exit(2)
