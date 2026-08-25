"""Small standard-library Gemini generateContent client."""

from __future__ import annotations

import base64
import json
import subprocess
import time
import urllib.error
import urllib.request
from io import BytesIO
from pathlib import Path
from typing import Any

from PIL import Image


IMAGE_MODEL = "gemini-3.1-flash-image"
RIG_MODEL = "gemini-3.5-flash"
_API_ROOT = "https://generativelanguage.googleapis.com/v1beta/models"


class GeminiError(RuntimeError):
    """A sanitized Gemini request or response failure."""


class GeminiTransportError(GeminiError):
    """Transport-level failure (network/HTTP); already retried, never re-retry."""


def read_api_key() -> str:
    """Read the API key from macOS Keychain without persisting it."""

    try:
        completed = subprocess.run(
            ["security", "find-generic-password", "-s", "gemini-api-key", "-w"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError) as error:
        raise GeminiError(
            "could not read Keychain item 'gemini-api-key'; add it before a live run"
        ) from error
    key = completed.stdout.strip()
    if not key:
        raise GeminiError("Keychain item 'gemini-api-key' is empty")
    return key


def _image_part(path: str | Path) -> dict[str, Any]:
    image_path = Path(path)
    suffix = image_path.suffix.lower()
    mime = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png"}.get(suffix)
    if mime is None:
        raise ValueError(f"unsupported input image type: {image_path.name}")
    return {
        "inlineData": {
            "mimeType": mime,
            "data": base64.b64encode(image_path.read_bytes()).decode("ascii"),
        }
    }


class GeminiClient:
    def __init__(self, api_key: str, *, retries: int = 3, timeout: float = 90):
        if not api_key:
            raise ValueError("api_key must be non-empty")
        if retries < 0:
            raise ValueError("retries must be non-negative")
        self._api_key = api_key
        self._retries = retries
        self._timeout = timeout

    def _generate(self, model: str, body: dict[str, Any]) -> dict[str, Any]:
        url = f"{_API_ROOT}/{model}:generateContent"
        request = urllib.request.Request(
            url,
            data=json.dumps(body).encode("utf-8"),
            headers={"Content-Type": "application/json", "x-goog-api-key": self._api_key},
            method="POST",
        )
        for attempt in range(self._retries + 1):
            try:
                with urllib.request.urlopen(request, timeout=self._timeout) as response:
                    payload = json.load(response)
                if not isinstance(payload, dict):
                    raise GeminiError(f"{model} returned a non-object response")
                return payload
            except urllib.error.HTTPError as error:
                retryable = error.code == 429 or 500 <= error.code < 600
                if not retryable or attempt == self._retries:
                    raise GeminiTransportError(f"{model} request failed with HTTP {error.code}") from error
            except (urllib.error.URLError, TimeoutError) as error:
                if attempt == self._retries:
                    raise GeminiTransportError(f"{model} request failed after retries") from error
            time.sleep(min(2**attempt, 8))
        raise AssertionError("retry loop should always return or raise")

    @staticmethod
    def _parts(payload: dict[str, Any]) -> list[dict[str, Any]]:
        try:
            parts = payload["candidates"][0]["content"]["parts"]
        except (KeyError, IndexError, TypeError) as error:
            raise GeminiError("Gemini response did not contain candidate content") from error
        if not isinstance(parts, list):
            raise GeminiError("Gemini response parts were malformed")
        return parts

    def _with_content_retries(self, operation: Any) -> Any:
        # transport failures retry inside _generate; content failures (missing
        # image, invalid bytes, invalid JSON) get their own retry budget here
        last: GeminiError | None = None
        for _ in range(self._retries + 1):
            try:
                return operation()
            except GeminiTransportError:
                raise  # transport already spent its own retry budget
            except GeminiError as error:
                last = error
        raise last if last is not None else AssertionError("unreachable")

    def generate_image(self, *, prompt: str, reference_images: list[Path]) -> Image.Image:
        return self._with_content_retries(
            lambda: self._generate_image_once(prompt=prompt, reference_images=reference_images)
        )

    def _generate_image_once(self, *, prompt: str, reference_images: list[Path]) -> Image.Image:
        parts: list[dict[str, Any]] = [{"text": prompt}]
        parts.extend(_image_part(path) for path in reference_images)
        payload = self._generate(
            IMAGE_MODEL,
            {
                "contents": [{"role": "user", "parts": parts}],
                "generationConfig": {"responseModalities": ["IMAGE"]},
            },
        )
        for part in self._parts(payload):
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                try:
                    image = Image.open(BytesIO(base64.b64decode(inline["data"])))
                    image.load()
                    return image
                except Exception as error:
                    raise GeminiError("Gemini returned invalid image bytes") from error
        raise GeminiError("Gemini response did not contain an image")

    def detect_rig(self, *, front_image: Path, side_image: Path) -> dict[str, Any]:
        return self._with_content_retries(
            lambda: self._detect_rig_once(front_image=front_image, side_image=side_image)
        )

    def _detect_rig_once(self, *, front_image: Path, side_image: Path) -> dict[str, Any]:
        with Image.open(front_image) as front, Image.open(side_image) as side:
            front_size = front.size
            side_size = side.size
        prompt = f"""Analyze these two transparent pixel-art pet images.
Image 1 is a front sitting pose ({front_size[0]}x{front_size[1]} pixels).
Image 2 is a side standing pose facing right ({side_size[0]}x{side_size[1]} pixels).
Return only JSON in this exact shape:
{{"species":"cat|dog","front":{{"boxes":{{"head":[x0,y0,x1,y1],"tail":[x0,y0,x1,y1],"leftFrontLeg":[x0,y0,x1,y1],"rightFrontLeg":[x0,y0,x1,y1]}}}},"side":{{"facing":"right","boxes":{{"head":[x0,y0,x1,y1],"tail":[x0,y0,x1,y1],"frontLeg":[x0,y0,x1,y1],"hindLeg":[x0,y0,x1,y1]}}}}}}
Coordinates are source-PNG pixel coordinates, x1/y1 exclusive. Head includes ears. Boxes must be tight, non-empty, and inside their image. Classify species as cat or dog only when clearly supported."""
        payload = self._generate(
            RIG_MODEL,
            {
                "contents": [
                    {
                        "role": "user",
                        "parts": [
                            {"text": prompt},
                            _image_part(front_image),
                            _image_part(side_image),
                        ],
                    }
                ],
                "generationConfig": {"responseMimeType": "application/json"},
            },
        )
        text = "".join(str(part.get("text", "")) for part in self._parts(payload)).strip()
        if text.startswith("```"):
            text = text.removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        try:
            result = json.loads(text)
        except json.JSONDecodeError as error:
            raise GeminiError("rig model returned invalid JSON") from error
        if not isinstance(result, dict):
            raise GeminiError("rig model JSON must be an object")
        _validate_rig_response_shape(result)
        return result


_FRONT_RIG_PARTS = ("head", "tail", "leftFrontLeg", "rightFrontLeg")
_SIDE_RIG_PARTS = ("head", "tail", "frontLeg", "hindLeg")


def _validate_rig_response_shape(result: dict[str, Any]) -> None:
    """Structurally-broken rig JSON must fail inside the content-retry layer."""

    for view, parts in (("front", _FRONT_RIG_PARTS), ("side", _SIDE_RIG_PARTS)):
        boxes = result.get(view, {}).get("boxes") if isinstance(result.get(view), dict) else None
        if not isinstance(boxes, dict) or set(boxes) != set(parts):
            raise GeminiError(f"rig model JSON is missing {view} boxes for: {', '.join(parts)}")
        for part in parts:
            box = boxes[part]
            if not isinstance(box, list) or len(box) != 4 or not all(
                isinstance(value, (int, float)) and not isinstance(value, bool) for value in box
            ):
                raise GeminiError(f"rig model JSON {view}.{part} must be [x0, y0, x1, y1]")
