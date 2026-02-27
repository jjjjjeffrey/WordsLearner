#!/usr/bin/env python3
"""
Phase 0 feasibility spike for multimodal lesson generation.

Validates:
- image generation with openai/gpt-image-1.5
- audio generation with inclusionai/ming-flash-omni-2.0

This script is intentionally provider-flexible. It defaults to OpenAI-compatible
paths under a ZenMux-style base URL, but captures raw responses so we can inspect
payload shapes and adjust parsers without changing app code.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_IMAGE_MODEL = "openai/gpt-image-1.5"
DEFAULT_AUDIO_MODEL = "inclusionai/ming-flash-omni-2.0"
DEFAULT_VERTEX_IMAGE_MODEL = "gemini-2.5-flash-image"
DEFAULT_ELEVENLABS_MODEL_ID = "eleven_multilingual_v2"
DEFAULT_ELEVENLABS_VOICE_ID = "JBFqnCBsd6RMkjVDRZzb"


def now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def json_dump(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def guess_ext_from_content_type(content_type: str | None, default: str) -> str:
    if not content_type:
        return default
    ct = content_type.lower()
    if "png" in ct:
        return ".png"
    if "jpeg" in ct or "jpg" in ct:
        return ".jpg"
    if "webp" in ct:
        return ".webp"
    if "mpeg" in ct or "mp3" in ct:
        return ".mp3"
    if "wav" in ct:
        return ".wav"
    if "mp4" in ct or "m4a" in ct or "aac" in ct:
        return ".m4a"
    if "ogg" in ct:
        return ".ogg"
    return default


def save_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


@dataclass
class HTTPResult:
    status: int
    content_type: str | None
    headers: dict[str, str]
    body: bytes
    elapsed_seconds: float


def http_request(
    method: str,
    url: str,
    headers: dict[str, str],
    payload: dict[str, Any] | None = None,
    timeout: float = 120.0,
) -> HTTPResult:
    data = None
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers = {**headers, "Content-Type": "application/json"}

    if "User-Agent" not in headers:
        headers = {
            **headers,
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
            "Accept": "application/json, */*",
        }
    request = urllib.request.Request(url=url, method=method, headers=headers, data=data)

    started = time.perf_counter()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read()
            elapsed = time.perf_counter() - started
            return HTTPResult(
                status=response.getcode(),
                content_type=response.headers.get("Content-Type"),
                headers=dict(response.headers.items()),
                body=body,
                elapsed_seconds=elapsed,
            )
    except urllib.error.HTTPError as error:
        body = error.read()
        elapsed = time.perf_counter() - started
        return HTTPResult(
            status=error.code,
            content_type=error.headers.get("Content-Type") if error.headers else None,
            headers=dict(error.headers.items()) if error.headers else {},
            body=body,
            elapsed_seconds=elapsed,
        )


def maybe_json(body: bytes) -> Any | None:
    try:
        return json.loads(body.decode("utf-8"))
    except Exception:
        return None


def extract_image_bytes(payload: Any) -> tuple[bytes | None, str]:
    if not isinstance(payload, dict):
        return None, "Payload is not JSON object"
    data = payload.get("data")
    if isinstance(data, list) and data:
        first = data[0]
        if isinstance(first, dict):
            b64 = first.get("b64_json") or first.get("b64")
            if isinstance(b64, str):
                try:
                    return base64.b64decode(b64), "Extracted image bytes from data[0].b64_json"
                except Exception as error:
                    return None, f"Failed to decode image base64: {error}"
            url = first.get("url")
            if isinstance(url, str):
                return None, f"Image returned URL only: {url}"
    return None, "No known image bytes field found"


def extract_vertex_image_bytes(payload: Any) -> tuple[bytes | None, str]:
    if not isinstance(payload, dict):
        return None, "Payload is not JSON object"
    candidates = payload.get("candidates")
    if not isinstance(candidates, list):
        return None, "Missing candidates list"
    for candidate in candidates:
        content = candidate.get("content") if isinstance(candidate, dict) else None
        parts = content.get("parts") if isinstance(content, dict) else None
        if not isinstance(parts, list):
            continue
        for part in parts:
            if not isinstance(part, dict):
                continue
            inline = part.get("inlineData")
            if isinstance(inline, dict) and isinstance(inline.get("data"), str):
                try:
                    return base64.b64decode(inline["data"]), "Extracted image bytes from candidates[].content.parts[].inlineData"
                except Exception as error:
                    return None, f"Failed to decode vertex inlineData: {error}"
    return None, "No image inlineData found in candidates"


def extract_audio_bytes(payload: Any) -> tuple[bytes | None, str]:
    if not isinstance(payload, dict):
        return None, "Payload is not JSON object"

    # Common variants to inspect
    candidates = [
        ("audio.data", payload.get("audio", {}).get("data") if isinstance(payload.get("audio"), dict) else None),
        ("audio.b64", payload.get("audio", {}).get("b64") if isinstance(payload.get("audio"), dict) else None),
        ("data[0].b64", (payload.get("data")[0].get("b64") if isinstance(payload.get("data"), list) and payload.get("data") and isinstance(payload.get("data")[0], dict) else None)),
        ("data[0].audio", (payload.get("data")[0].get("audio") if isinstance(payload.get("data"), list) and payload.get("data") and isinstance(payload.get("data")[0], dict) else None)),
    ]
    for label, candidate in candidates:
        if isinstance(candidate, str):
            try:
                return base64.b64decode(candidate), f"Extracted audio bytes from {label}"
            except Exception as error:
                return None, f"Failed to decode audio base64 from {label}: {error}"

    return None, "No known audio bytes field found"


def write_http_debug(prefix: Path, result: HTTPResult) -> None:
    meta = {
        "status": result.status,
        "content_type": result.content_type,
        "elapsed_seconds": round(result.elapsed_seconds, 3),
        "headers": result.headers,
    }
    json_dump(prefix.with_suffix(".meta.json"), meta)
    payload = maybe_json(result.body)
    if payload is not None:
        json_dump(prefix.with_suffix(".response.json"), payload)
    else:
        prefix.with_suffix(".response.bin").write_bytes(result.body)


def fetch_url_bytes(url: str, headers: dict[str, str], timeout: float = 120.0) -> HTTPResult:
    if "User-Agent" not in headers:
        headers = {
            **headers,
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
            "Accept": "*/*",
        }
    request = urllib.request.Request(url=url, method="GET", headers=headers)
    started = time.perf_counter()
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read()
        elapsed = time.perf_counter() - started
        return HTTPResult(
            status=response.getcode(),
            content_type=response.headers.get("Content-Type"),
            headers=dict(response.headers.items()),
            body=body,
            elapsed_seconds=elapsed,
        )


def run_image_case(args: argparse.Namespace, out_dir: Path, auth_headers: dict[str, str]) -> dict[str, Any]:
    prompt = (
        "Simple educational illustration, clean style. "
        "A child is feeding a ticket into a train station machine. "
        "Clear focus on the action. Minimal background clutter."
    )
    if args.image_protocol == "vertex":
        endpoint = urllib.parse.urljoin(
            args.base_url.rstrip("/") + "/",
            f"publishers/{args.vertex_image_provider}/models/{args.vertex_image_model}:generateContent",
        )
        payload = {
            "contents": [
                {
                    "role": "user",
                    "parts": [{"text": prompt}],
                }
            ],
            "generationConfig": {
                "responseModalities": ["TEXT", "IMAGE"]
            },
        }
        model_label = f"{args.vertex_image_provider}/{args.vertex_image_model}"
    else:
        endpoint = urllib.parse.urljoin(args.base_url.rstrip("/") + "/", args.image_endpoint.lstrip("/"))
        payload = {
            "model": args.image_model,
            "prompt": prompt,
            "size": args.image_size,
        }
        model_label = args.image_model

    result = http_request("POST", endpoint, auth_headers, payload)
    debug_prefix = out_dir / "image_case"
    write_http_debug(debug_prefix, result)

    summary: dict[str, Any] = {
        "endpoint": endpoint,
        "model": model_label,
        "elapsed_seconds": round(result.elapsed_seconds, 3),
        "status": result.status,
        "content_type": result.content_type,
        "success": False,
        "media_path": None,
        "notes": [],
    }

    if result.status < 200 or result.status >= 300:
        summary["notes"].append("HTTP error; see image_case.response.*")
        return summary

    # Some providers may return binary image directly.
    if result.content_type and result.content_type.lower().startswith("image/"):
        ext = guess_ext_from_content_type(result.content_type, ".png")
        media_path = out_dir / f"image_output{ext}"
        save_bytes(media_path, result.body)
        summary["success"] = True
        summary["media_path"] = str(media_path)
        summary["notes"].append("Binary image response")
        return summary

    payload_json = maybe_json(result.body)
    if payload_json is None:
        summary["notes"].append("Non-JSON non-image response")
        return summary

    if args.image_protocol == "vertex":
        image_bytes, note = extract_vertex_image_bytes(payload_json)
    else:
        image_bytes, note = extract_image_bytes(payload_json)
    summary["notes"].append(note)
    if image_bytes:
        media_path = out_dir / "image_output.png"
        save_bytes(media_path, image_bytes)
        summary["success"] = True
        summary["media_path"] = str(media_path)
        return summary

    data = payload_json.get("data") if isinstance(payload_json, dict) else None
    if isinstance(data, list) and data and isinstance(data[0], dict) and isinstance(data[0].get("url"), str):
        image_url = data[0]["url"]
        try:
            fetched = fetch_url_bytes(image_url, {})
            write_http_debug(out_dir / "image_url_fetch", fetched)
            if fetched.status >= 200 and fetched.status < 300 and fetched.content_type and fetched.content_type.lower().startswith("image/"):
                ext = guess_ext_from_content_type(fetched.content_type, ".png")
                media_path = out_dir / f"image_output{ext}"
                save_bytes(media_path, fetched.body)
                summary["success"] = True
                summary["media_path"] = str(media_path)
                summary["notes"].append("Fetched image from returned URL")
        except Exception as error:
            summary["notes"].append(f"Failed to fetch returned URL: {error}")
    return summary


def run_audio_case(args: argparse.Namespace, out_dir: Path, auth_headers: dict[str, str]) -> dict[str, Any]:
    text = (
        "Look at this scene. The child feeds a ticket into the machine. "
        "Here, feed means to put something into a slot or machine."
    )
    if args.audio_provider == "elevenlabs":
        endpoint = urllib.parse.urljoin(
            args.elevenlabs_base_url.rstrip("/") + "/",
            f"v1/text-to-speech/{args.elevenlabs_voice_id}",
        )
        elevenlabs_key = os.environ.get(args.elevenlabs_api_key_env, "").strip()
        if not elevenlabs_key:
            return {
                "endpoint": endpoint,
                "model": args.elevenlabs_model_id,
                "elapsed_seconds": 0.0,
                "status": 0,
                "content_type": None,
                "success": False,
                "media_path": None,
                "notes": [f"Missing ElevenLabs API key in env var {args.elevenlabs_api_key_env}"],
            }
        elevenlabs_headers = {
            "xi-api-key": elevenlabs_key,
            "Accept": "audio/mpeg",
        }
        payload = {
            "text": text,
            "model_id": args.elevenlabs_model_id,
        }
        result = http_request("POST", endpoint, elevenlabs_headers, payload)
        model_label = args.elevenlabs_model_id
    else:
        endpoint = urllib.parse.urljoin(args.base_url.rstrip("/") + "/", args.audio_endpoint.lstrip("/"))
        payload = {
            "model": args.audio_model,
            "input": text,
            "voice": args.audio_voice,
            "format": args.audio_format,
        }
        result = http_request("POST", endpoint, auth_headers, payload)
        model_label = args.audio_model
    debug_prefix = out_dir / "audio_case"
    write_http_debug(debug_prefix, result)

    summary: dict[str, Any] = {
        "endpoint": endpoint,
        "model": model_label,
        "elapsed_seconds": round(result.elapsed_seconds, 3),
        "status": result.status,
        "content_type": result.content_type,
        "success": False,
        "media_path": None,
        "notes": [],
    }

    if result.status < 200 or result.status >= 300:
        summary["notes"].append("HTTP error; see audio_case.response.*")
        return summary

    if result.content_type and result.content_type.lower().startswith("audio/"):
        ext = guess_ext_from_content_type(result.content_type, ".m4a")
        media_path = out_dir / f"audio_output{ext}"
        save_bytes(media_path, result.body)
        summary["success"] = True
        summary["media_path"] = str(media_path)
        summary["notes"].append("Binary audio response")
        return summary

    payload_json = maybe_json(result.body)
    if payload_json is None:
        summary["notes"].append("Non-JSON non-audio response")
        return summary

    audio_bytes, note = extract_audio_bytes(payload_json)
    summary["notes"].append(note)
    if audio_bytes:
        ext = f".{args.audio_format}" if not args.audio_format.startswith(".") else args.audio_format
        media_path = out_dir / f"audio_output{ext}"
        save_bytes(media_path, audio_bytes)
        summary["success"] = True
        summary["media_path"] = str(media_path)
    return summary


def run_malformed_case(args: argparse.Namespace, out_dir: Path, auth_headers: dict[str, str]) -> dict[str, Any]:
    if args.image_protocol == "vertex":
        endpoint = urllib.parse.urljoin(
            args.base_url.rstrip("/") + "/",
            f"publishers/{args.vertex_image_provider}/models/{args.vertex_image_model}:generateContent",
        )
        payload = {"contents": []}  # intentionally malformed
    else:
        endpoint = urllib.parse.urljoin(args.base_url.rstrip("/") + "/", args.image_endpoint.lstrip("/"))
        payload = {"model": args.image_model}  # intentionally malformed (missing prompt)
    result = http_request("POST", endpoint, auth_headers, payload)
    write_http_debug(out_dir / "malformed_image_case", result)
    return {
        "endpoint": endpoint,
        "elapsed_seconds": round(result.elapsed_seconds, 3),
        "status": result.status,
        "content_type": result.content_type,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Phase 0 multimodal feasibility spike")
    parser.add_argument("--base-url", default="https://zenmux.ai/api/v1", help="Provider API base URL")
    parser.add_argument("--image-protocol", choices=["openai", "vertex"], default="vertex", help="Image API protocol")
    parser.add_argument("--api-key-env", default="AIHUBMIX_API_KEY", help="Environment variable holding provider API key")
    parser.add_argument("--image-endpoint", default="/images/generations", help="Image generation endpoint path")
    parser.add_argument("--audio-endpoint", default="/audio/speech", help="Audio generation endpoint path")
    parser.add_argument("--image-model", default=DEFAULT_IMAGE_MODEL)
    parser.add_argument("--audio-model", default=DEFAULT_AUDIO_MODEL)
    parser.add_argument("--audio-provider", choices=["zenmux", "elevenlabs"], default="elevenlabs")
    parser.add_argument("--vertex-image-provider", default="google")
    parser.add_argument("--vertex-image-model", default=DEFAULT_VERTEX_IMAGE_MODEL)
    parser.add_argument("--image-size", default="1024x1024")
    parser.add_argument("--audio-format", default="m4a")
    parser.add_argument("--audio-voice", default="alloy")
    parser.add_argument("--elevenlabs-base-url", default="https://api.elevenlabs.io")
    parser.add_argument("--elevenlabs-api-key-env", default="ELEVENLABS_API_KEY")
    parser.add_argument("--elevenlabs-model-id", default=DEFAULT_ELEVENLABS_MODEL_ID)
    parser.add_argument("--elevenlabs-voice-id", default=DEFAULT_ELEVENLABS_VOICE_ID)
    parser.add_argument("--output-dir", default=None, help="Directory for outputs (default: ./.tmp/phase0-<timestamp>)")
    parser.add_argument("--skip-malformed", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    api_key = os.environ.get(args.api_key_env, "").strip()
    if not api_key:
        print(
            f"Missing API key in env var {args.api_key_env}. "
            f"Example: export {args.api_key_env}=...",
            file=sys.stderr,
        )
        return 2

    root = Path(args.output_dir) if args.output_dir else Path(".tmp") / f"phase0-multimodal-spike-{now_utc()}"
    root.mkdir(parents=True, exist_ok=True)

    auth_headers = {"Authorization": f"Bearer {api_key}"}

    run_summary: dict[str, Any] = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "base_url": args.base_url,
        "image_model": args.image_model,
        "image_protocol": args.image_protocol,
        "vertex_image_provider": args.vertex_image_provider,
        "vertex_image_model": args.vertex_image_model,
        "audio_model": args.audio_model,
        "audio_provider": args.audio_provider,
        "elevenlabs_model_id": args.elevenlabs_model_id,
        "elevenlabs_voice_id": args.elevenlabs_voice_id,
        "image_endpoint": args.image_endpoint,
        "audio_endpoint": args.audio_endpoint,
    }

    print(f"[phase0] output dir: {root}")
    print("[phase0] running image case...")
    image_summary = run_image_case(args, root, auth_headers)
    run_summary["image_case"] = image_summary

    print("[phase0] running audio case...")
    audio_summary = run_audio_case(args, root, auth_headers)
    run_summary["audio_case"] = audio_summary

    if not args.skip_malformed:
        print("[phase0] running malformed request case...")
        run_summary["malformed_case"] = run_malformed_case(args, root, auth_headers)

    run_summary["finished_at"] = datetime.now(timezone.utc).isoformat()
    run_summary["overall_pass_candidate"] = bool(
        image_summary.get("success") and audio_summary.get("success")
    )

    json_dump(root / "summary.json", run_summary)
    print(json.dumps(run_summary, indent=2))
    print(f"[phase0] summary saved to {root / 'summary.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
