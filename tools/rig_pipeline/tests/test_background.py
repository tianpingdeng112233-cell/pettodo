from PIL import Image, ImageDraw

from tools.rig_pipeline.background import remove_solid_background


def test_remove_solid_background_keeps_subject_and_clears_connected_background():
    source = Image.new("RGB", (24, 24), (242, 231, 210))
    draw = ImageDraw.Draw(source)
    draw.rectangle((7, 5, 16, 20), fill=(80, 45, 30))
    draw.rectangle((10, 9, 12, 12), fill=(242, 231, 210))  # enclosed highlight

    result = remove_solid_background(source, threshold=12)

    assert result.mode == "RGBA"
    assert result.getpixel((0, 0))[3] == 0
    assert result.getpixel((23, 23))[3] == 0
    assert result.getpixel((8, 8))[3] == 255
    # Flood fill must not erase a background-coloured region enclosed by the pet.
    assert result.getpixel((11, 10))[3] == 255


def test_remove_solid_background_uses_all_four_corner_colours():
    source = Image.new("RGB", (10, 10), (240, 240, 240))
    source.putpixel((9, 9), (210, 220, 230))
    source.putpixel((8, 9), (210, 220, 230))
    source.putpixel((9, 8), (210, 220, 230))
    result = remove_solid_background(source, threshold=5)
    assert result.getpixel((9, 9))[3] == 0
