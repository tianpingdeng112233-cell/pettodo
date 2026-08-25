import json
import zipfile

from PIL import Image

from tools.rig_pipeline.pack import CANONICAL_IMAGE_NAMES, build_pack


def _write_rgba(path, size=(32, 24)):
    # transparent canvas with an opaque subject, per the v3 contract
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    for x in range(4, size[0] - 4):
        for y in range(2, size[1] - 2):
            image.putpixel((x, y), (200, 120, 80, 255))
    image.save(path)


def _write_opaque(path, size=(32, 24)):
    Image.new("RGBA", size, (200, 120, 80, 255)).save(path)


def test_build_pack_is_flat_and_contract_compliant(tmp_path):
    images = {}
    for name in CANONICAL_IMAGE_NAMES:
        path = tmp_path / name
        _write_rgba(path)
        images[name] = path

    rig = {
        "rigVersion": 1,
        "front": {
            "groundY": 23,
            "boxes": {
                "head": [8, 2, 24, 12],
                "tail": [25, 10, 31, 21],
                "leftFrontLeg": [10, 12, 15, 23],
                "rightFrontLeg": [17, 12, 22, 23],
            },
            "pivots": {"head": [16, 12], "tail": [25, 15.5]},
        },
        "side": {
            "groundY": 23,
            "facing": "right",
            "boxes": {
                "head": [20, 2, 31, 12],
                "tail": [1, 8, 8, 18],
                "frontLeg": [21, 12, 26, 23],
                "hindLeg": [8, 12, 13, 23],
            },
            "pivots": {
                "head": [25.5, 12],
                "tail": [8, 13],
                "frontLeg": [23.5, 12],
                "hindLeg": [10.5, 12],
            },
        },
    }
    output = tmp_path / "miso.pettodopet"

    build_pack(
        output,
        pack={
            "formatVersion": 3,
            "id": "miso",
            "display_name": "Miso",
            "species": "cat",
            "treat": {"name": "salmon bite", "emoji": "🐟"},
        },
        rig=rig,
        images=images,
    )

    with zipfile.ZipFile(output) as archive:
        assert set(archive.namelist()) == {
            "pack.json",
            "rig.json",
            *CANONICAL_IMAGE_NAMES,
        }
        assert all("/" not in name for name in archive.namelist())
        assert json.loads(archive.read("pack.json")) == {
            "formatVersion": 3,
            "id": "miso",
            "display_name": "Miso",
            "species": "cat",
            "treat": {"name": "salmon bite", "emoji": "🐟"},
        }
        assert json.loads(archive.read("rig.json"))["rigVersion"] == 1
        for name in CANONICAL_IMAGE_NAMES:
            assert Image.open(archive.open(name)).mode == "RGBA"


def test_build_pack_rejects_invalid_metadata(tmp_path):
    images = {}
    for name in CANONICAL_IMAGE_NAMES:
        path = tmp_path / name
        _write_rgba(path)
        images[name] = path

    try:
        build_pack(
            tmp_path / "bad.pettodopet",
            pack={"formatVersion": 2},
            rig={"rigVersion": 1},
            images=images,
        )
    except ValueError as error:
        assert "pack.json" in str(error)
    else:
        raise AssertionError("invalid metadata should be rejected")


def _pack():
    return {
        "formatVersion": 3,
        "id": "miso",
        "display_name": "Miso",
        "species": "cat",
        "treat": {"name": "salmon bite", "emoji": "🐟"},
    }


def _rig():
    return {
        "rigVersion": 1,
        "front": {
            "groundY": 23,
            "boxes": {
                "head": [8, 2, 24, 12],
                "tail": [25, 10, 31, 21],
                "leftFrontLeg": [10, 12, 15, 23],
                "rightFrontLeg": [17, 12, 22, 23],
            },
            "pivots": {"head": [16, 12], "tail": [25, 15.5]},
        },
        "side": {
            "groundY": 23,
            "facing": "right",
            "boxes": {
                "head": [20, 2, 31, 12],
                "tail": [1, 8, 8, 18],
                "frontLeg": [21, 12, 26, 23],
                "hindLeg": [8, 12, 13, 23],
            },
            "pivots": {
                "head": [25.5, 12],
                "tail": [8, 13],
                "frontLeg": [23.5, 12],
                "hindLeg": [10.5, 12],
            },
        },
    }


def test_build_pack_rejects_opaque_canonical_image(tmp_path):
    import pytest
    images = {}
    for name in CANONICAL_IMAGE_NAMES:
        path = tmp_path / name
        _write_rgba(path)
        images[name] = path
    _write_opaque(tmp_path / "front-open.png")  # violates transparency contract
    with pytest.raises(ValueError, match="transparency"):
        build_pack(tmp_path / "x.pettodopet", pack=_pack(), rig=_rig(), images=images)


def test_pack_metadata_rejects_float_format_version():
    import pytest
    from tools.rig_pipeline.pack import validate_pack_metadata
    bad = dict(_pack())
    bad["formatVersion"] = 3.0
    with pytest.raises(ValueError, match="integer 3"):
        validate_pack_metadata(bad)
