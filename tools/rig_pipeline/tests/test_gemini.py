import base64
import io
import json
from unittest.mock import patch

from PIL import Image

from tools.rig_pipeline.gemini import GeminiClient, read_api_key


def _image_data():
    buffer = io.BytesIO()
    Image.new("RGB", (4, 4), "red").save(buffer, format="PNG")
    return base64.b64encode(buffer.getvalue()).decode("ascii")


@patch("tools.rig_pipeline.gemini.urllib.request.urlopen")
def test_generate_image_uses_mocked_transport_and_key_header(urlopen, tmp_path):
    response = io.BytesIO(
        json.dumps(
            {
                "candidates": [
                    {"content": {"parts": [{"inlineData": {"mimeType": "image/png", "data": _image_data()}}]}}
                ]
            }
        ).encode("utf-8")
    )
    urlopen.return_value = response
    reference = tmp_path / "pet.png"
    Image.new("RGB", (4, 4), "gray").save(reference)

    result = GeminiClient("memory-only-key", retries=0).generate_image(
        prompt="canonical pet", reference_images=[reference]
    )

    request = urlopen.call_args.args[0]
    assert result.size == (4, 4)
    assert "memory-only-key" not in request.full_url
    assert request.get_header("X-goog-api-key") == "memory-only-key"
    body = json.loads(request.data)
    assert body["generationConfig"] == {"responseModalities": ["IMAGE"]}


@patch("tools.rig_pipeline.gemini.subprocess.run")
def test_read_api_key_uses_expected_keychain_service(run):
    run.return_value.stdout = "secret-from-keychain\n"
    assert read_api_key() == "secret-from-keychain"
    assert run.call_args.args[0] == [
        "security",
        "find-generic-password",
        "-s",
        "gemini-api-key",
        "-w",
    ]


@patch("tools.rig_pipeline.gemini.urllib.request.urlopen")
def test_generate_image_retries_content_level_failures(urlopen, tmp_path):
    empty = io.BytesIO(json.dumps({"candidates": [{"content": {"parts": [{"text": "no image"}]}}]}).encode())
    good = io.BytesIO(
        json.dumps(
            {"candidates": [{"content": {"parts": [{"inlineData": {"mimeType": "image/png", "data": _image_data()}}]}}]}
        ).encode()
    )
    urlopen.side_effect = [empty, good]
    reference = tmp_path / "pet.png"
    Image.new("RGB", (4, 4), "gray").save(reference)

    result = GeminiClient("memory-only-key", retries=1).generate_image(
        prompt="canonical pet", reference_images=[reference]
    )
    assert result.size == (4, 4)
    assert urlopen.call_count == 2


@patch("tools.rig_pipeline.gemini.time.sleep")
@patch("tools.rig_pipeline.gemini.urllib.request.urlopen")
def test_permanent_network_failure_is_not_amplified(urlopen, _sleep, tmp_path):
    import urllib.error
    import pytest
    from tools.rig_pipeline.gemini import GeminiTransportError

    urlopen.side_effect = urllib.error.URLError("down")
    reference = tmp_path / "pet.png"
    Image.new("RGB", (4, 4), "gray").save(reference)
    client = GeminiClient("memory-only-key", retries=3)
    with pytest.raises(GeminiTransportError):
        client.generate_image(prompt="p", reference_images=[reference])
    assert urlopen.call_count == 4  # retries + 1, no content-layer re-amplification


@patch("tools.rig_pipeline.gemini.urllib.request.urlopen")
def test_non_retryable_http_status_requests_once(urlopen, tmp_path):
    import urllib.error
    import pytest
    from tools.rig_pipeline.gemini import GeminiTransportError

    urlopen.side_effect = urllib.error.HTTPError("u", 400, "bad", {}, None)
    reference = tmp_path / "pet.png"
    Image.new("RGB", (4, 4), "gray").save(reference)
    with pytest.raises(GeminiTransportError):
        GeminiClient("memory-only-key", retries=3).generate_image(prompt="p", reference_images=[reference])
    assert urlopen.call_count == 1


@patch("tools.rig_pipeline.gemini.urllib.request.urlopen")
def test_detect_rig_retries_structurally_broken_json(urlopen, tmp_path):
    def _response(payload):
        return io.BytesIO(json.dumps({"candidates": [{"content": {"parts": [{"text": json.dumps(payload)}]}}]}).encode())

    good = {
        "species": "cat",
        "front": {"boxes": {"head": [0, 0, 2, 2], "tail": [2, 0, 4, 2], "leftFrontLeg": [0, 2, 2, 4], "rightFrontLeg": [2, 2, 4, 4]}},
        "side": {"facing": "right", "boxes": {"head": [0, 0, 2, 2], "tail": [2, 0, 4, 2], "frontLeg": [0, 2, 2, 4], "hindLeg": [2, 2, 4, 4]}},
    }
    urlopen.side_effect = [_response({}), _response(good)]
    front = tmp_path / "front.png"
    side = tmp_path / "side.png"
    Image.new("RGBA", (4, 4)).save(front)
    Image.new("RGBA", (4, 4)).save(side)

    result = GeminiClient("memory-only-key", retries=1).detect_rig(front_image=front, side_image=side)
    assert result["front"]["boxes"]["head"] == [0, 0, 2, 2]
    assert urlopen.call_count == 2
