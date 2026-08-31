import json

from PIL import Image, ImageDraw

from tools.rig_pipeline.normalize import (
    FRONT_BASELINE,
    FRONT_CANVAS,
    FRONT_CONTENT_BOX,
    normalize_pack_dir,
    strip_background_halo,
)


BG = (12, 200, 212)
BODY = (40, 40, 45)
OUTLINE = (20, 15, 12)


def _canonical(size=(200, 120), body_box=(60, 30, 140, 100), halo_rings=2) -> Image.Image:
    """A background-removed canonical: body + dark outline + leftover bg halo."""

    image = Image.new("RGBA", size, (*BG, 0))
    draw = ImageDraw.Draw(image)
    x0, y0, x1, y1 = body_box
    for ring in range(halo_rings):
        grow = halo_rings - ring
        mix = tuple((b + p) // 2 for b, p in zip(BG, BODY))
        draw.rectangle((x0 - grow, y0 - grow, x1 + grow, y1 + grow), fill=(*mix, 255))
    draw.rectangle(body_box, fill=(*OUTLINE, 255))
    draw.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), fill=(*BODY, 255))
    return image


def test_strip_background_halo_removes_halo_and_keeps_outline():
    result = strip_background_halo(_canonical())

    assert result.getpixel((58, 65))[3] == 0  # halo ring gone
    assert result.getpixel((59, 65))[3] == 0
    assert result.getpixel((60, 65)) == (*OUTLINE, 255)  # intentional outline kept
    assert result.getpixel((100, 65)) == (*BODY, 255)


def test_strip_background_halo_keeps_thin_features():
    image = _canonical(halo_rings=0)
    draw = ImageDraw.Draw(image)
    draw.line((100, 29, 100, 10), fill=(*OUTLINE, 255), width=1)  # whisker

    result = strip_background_halo(image)

    assert result.getpixel((100, 15))[3] == 255


def test_normalize_pack_dir_reframes_front_and_rig(tmp_path):
    for name in ("front-open", "front-closed"):
        _canonical().save(tmp_path / f"{name}.png")
    _canonical(body_box=(40, 60, 180, 110)).save(tmp_path / "sleep.png")
    _canonical().save(tmp_path / "side.png")
    rig = {
        "rigVersion": 1,
        "front": {
            "groundY": 100,
            "boxes": {"head": [60, 30, 140, 60]},
            "pivots": {"head": [100, 60]},
        },
    }
    (tmp_path / "rig.json").write_text(json.dumps(rig))

    normalize_pack_dir(tmp_path)

    front = Image.open(tmp_path / "front-open.png").convert("RGBA")
    assert front.size == FRONT_CANVAS
    box = front.getchannel("A").getbbox()
    assert box[3] == FRONT_BASELINE
    assert max(box[2] - box[0], box[3] - box[1]) in (FRONT_CONTENT_BOX[0], FRONT_CONTENT_BOX[0] - 1)
    closed = Image.open(tmp_path / "front-closed.png").convert("RGBA")
    assert closed.size == FRONT_CANVAS

    reframed = json.loads((tmp_path / "rig.json").read_text())["front"]
    # groundY indexes the bottom content row, whose top edge lands one scaled
    # pixel above the baseline — this fixture's ~11.5x scale magnifies that.
    assert FRONT_BASELINE - 12 <= reframed["groundY"] <= FRONT_BASELINE
    head = reframed["boxes"]["head"]
    assert 0 <= head[0] < head[2] <= FRONT_CANVAS[0]
    assert 0 <= head[1] < head[3] <= FRONT_CANVAS[1]
    # Side canvas is deliberately untouched (its framing already fits the display box).
    assert Image.open(tmp_path / "side.png").size == (200, 120)
