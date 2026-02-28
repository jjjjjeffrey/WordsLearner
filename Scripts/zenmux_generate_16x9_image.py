#!/usr/bin/env python3
"""
Generate a 16:9 image via ZenMux + google/gemini-3.1-flash-image-preview.

Usage:
  export ZENMUX_API_KEY='...'
  python Scripts/zenmux_generate_16x9_image.py \
    --prompt "Create a vivid storyboard frame for two words" \
    --output /tmp/lesson_frame.png

Behavior:
- Requests 16:9 via model config + prompt constraints.
- Validates output aspect ratio.
- Retries generation if ratio is not 16:9.
- Optional fallback center-crop to 16:9 (requires Pillow).
"""

from __future__ import annotations

import argparse
import base64
import os
import struct
from pathlib import Path
from typing import Any

from google import genai
from google.genai import types

MODEL = "google/gemini-3.1-flash-image-preview"
BASE_URL = "https://zenmux.ai/api/vertex-ai"
TARGET_W = 16
TARGET_H = 9


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prompt", required=True, help="Image prompt")
    parser.add_argument("--output", required=True, help="Output image path")
    parser.add_argument("--max-attempts", type=int, default=4)
    parser.add_argument(
        "--force-crop",
        action="store_true",
        help="If model still does not return 16:9, center-crop to 16:9 (requires Pillow).",
    )
    parser.add_argument(
        "--api-key",
        default=os.getenv("ZENMUX_API_KEY", ""),
        help="ZenMux API key (defaults to env ZENMUX_API_KEY)",
    )
    return parser.parse_args()


def build_client(api_key: str) -> genai.Client:
    return genai.Client(
        api_key=api_key,
        vertexai=True,
        http_options=types.HttpOptions(api_version="v1", base_url=BASE_URL),
    )


def build_prompt(user_prompt: str, attempt: int) -> str:
    strict = "" if attempt == 1 else "CRITICAL: Return a landscape 16:9 image."
    return (
        f"{user_prompt}\n\n"
        "Visual constraints:\n"
        "- cinematic storyboard frame\n"
        "- landscape 16:9 composition (video style)\n"
        "- no text, no subtitles, no letters, no watermark\n"
        f"{strict}"
    )


def extract_image_bytes(response: Any) -> bytes:
    parts = getattr(response, "parts", None)
    if not parts:
        raise RuntimeError("No response.parts found")

    for part in parts:
        inline_data = getattr(part, "inline_data", None)
        if inline_data is not None:
            data = getattr(inline_data, "data", None)
            if isinstance(data, bytes):
                return data
            if isinstance(data, str):
                try:
                    return base64.b64decode(data)
                except Exception:
                    pass

        # SDK convenience fallback
        as_image = getattr(part, "as_image", None)
        if callable(as_image):
            image_obj = as_image()
            if image_obj is not None:
                from io import BytesIO

                buf = BytesIO()
                image_obj.save(buf, format="PNG")
                return buf.getvalue()

    # Raw-candidate fallback for provider-specific response shapes.
    candidates = getattr(response, "candidates", None)
    if isinstance(candidates, list):
        for candidate in candidates:
            content = getattr(candidate, "content", None)
            parts = getattr(content, "parts", None)
            if not isinstance(parts, list):
                continue
            for part in parts:
                inline_data = getattr(part, "inline_data", None)
                if inline_data is None:
                    continue
                data = getattr(inline_data, "data", None)
                if isinstance(data, bytes):
                    return data
                if isinstance(data, str):
                    try:
                        return base64.b64decode(data)
                    except Exception:
                        pass

    raise RuntimeError("No image binary found in response parts")


def png_size(data: bytes) -> tuple[int, int] | None:
    sig = b"\x89PNG\r\n\x1a\n"
    if len(data) >= 24 and data.startswith(sig):
        width, height = struct.unpack(">II", data[16:24])
        return int(width), int(height)
    return None


def jpeg_size(data: bytes) -> tuple[int, int] | None:
    if len(data) < 4 or data[0] != 0xFF or data[1] != 0xD8:
        return None

    i = 2
    while i + 9 < len(data):
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        i += 2

        if marker in {0xD8, 0xD9}:
            continue

        if i + 2 > len(data):
            return None
        seg_len = (data[i] << 8) + data[i + 1]
        if seg_len < 2 or i + seg_len > len(data):
            return None

        if marker in {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}:
            if i + 7 > len(data):
                return None
            height = (data[i + 3] << 8) + data[i + 4]
            width = (data[i + 5] << 8) + data[i + 6]
            return int(width), int(height)

        i += seg_len

    return None


def webp_size(data: bytes) -> tuple[int, int] | None:
    if len(data) < 30 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        return None
    chunk = data[12:16]
    if chunk == b"VP8X" and len(data) >= 30:
        w = 1 + int.from_bytes(data[24:27], "little")
        h = 1 + int.from_bytes(data[27:30], "little")
        return w, h
    return None


def detect_size(data: bytes) -> tuple[int, int]:
    for fn in (png_size, jpeg_size, webp_size):
        size = fn(data)
        if size:
            return size
    raise RuntimeError("Unsupported image format for size detection")


def ratio_ok(width: int, height: int, tolerance: float = 0.02) -> bool:
    ratio = width / height
    target = TARGET_W / TARGET_H
    return abs(ratio - target) <= tolerance


def center_crop_to_16_9(input_path: Path, output_path: Path) -> tuple[int, int]:
    try:
        from PIL import Image
    except Exception as exc:
        raise RuntimeError("Pillow is required for --force-crop. Install with: pip install pillow") from exc

    with Image.open(input_path) as img:
        w, h = img.size
        target_ratio = TARGET_W / TARGET_H
        current_ratio = w / h

        if current_ratio > target_ratio:
            # Too wide -> crop sides
            new_w = int(h * target_ratio)
            left = (w - new_w) // 2
            box = (left, 0, left + new_w, h)
        else:
            # Too tall -> crop top/bottom
            new_h = int(w / target_ratio)
            top = (h - new_h) // 2
            box = (0, top, w, top + new_h)

        cropped = img.crop(box)
        cropped.save(output_path)
        return cropped.size


def main() -> int:
    args = parse_args()

    if not args.api_key:
        print("ERROR: Missing API key. Set --api-key or ZENMUX_API_KEY.")
        return 1

    output_path = Path(args.output).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    client = build_client(args.api_key)

    last_image_bytes: bytes | None = None
    last_size: tuple[int, int] | None = None

    for attempt in range(1, args.max_attempts + 1):
        prompt = build_prompt(args.prompt, attempt)

        response = client.models.generate_content(
            model=MODEL,
            contents=[prompt],
            config=types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
                # Key part: request 16:9 from API, not just from prompt text.
                image_config=types.ImageConfig(aspect_ratio="16:9"),
            ),
        )

        image_bytes = extract_image_bytes(response)
        width, height = detect_size(image_bytes)
        last_image_bytes = image_bytes
        last_size = (width, height)

        output_path.write_bytes(image_bytes)
        print(f"Attempt {attempt}: saved {output_path} ({width}x{height})")

        if ratio_ok(width, height):
            print("SUCCESS: image is 16:9")
            return 0

    if args.force_crop and last_image_bytes is not None:
        output_path.write_bytes(last_image_bytes)
        new_w, new_h = center_crop_to_16_9(output_path, output_path)
        print(
            "WARNING: model did not return 16:9 after retries; "
            f"applied center crop to 16:9 -> {new_w}x{new_h}"
        )
        return 0

    if last_size:
        w, h = last_size
        print(
            "ERROR: model did not return 16:9 after retries. "
            f"Last size: {w}x{h}. Re-run with --force-crop to enforce output ratio."
        )
    else:
        print("ERROR: image generation failed; no image produced.")

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
