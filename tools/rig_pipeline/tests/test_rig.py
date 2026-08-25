import pytest

from tools.rig_pipeline.rig import build_rig


def test_build_rig_derives_contract_pivots():
    rig = build_rig(
        front_boxes={
            "head": [10, 4, 30, 20],
            "tail": [32, 15, 40, 31],
            "leftFrontLeg": [12, 20, 18, 40],
            "rightFrontLeg": [22, 20, 28, 40],
        },
        side_boxes={
            "head": [25, 5, 42, 21],
            "tail": [2, 12, 12, 30],
            "frontLeg": [28, 21, 34, 40],
            "hindLeg": [12, 21, 18, 40],
        },
        front_size=(48, 42),
        side_size=(48, 42),
        front_ground_y=40,
        side_ground_y=40,
        side_facing="right",
    )

    assert rig["rigVersion"] == 1
    assert rig["front"]["pivots"] == {
        "head": [20, 20],
        "tail": [32, 23],
    }
    assert rig["side"]["pivots"] == {
        "head": [33.5, 21],
        "tail": [12, 21],
        "frontLeg": [31, 21],
        "hindLeg": [15, 21],
    }


def test_build_rig_rejects_out_of_bounds_box():
    with pytest.raises(ValueError, match="within image bounds"):
        build_rig(
            front_boxes={
                "head": [-1, 4, 30, 20],
                "tail": [32, 15, 40, 31],
                "leftFrontLeg": [12, 20, 18, 40],
                "rightFrontLeg": [22, 20, 28, 40],
            },
            side_boxes={
                "head": [25, 5, 42, 21],
                "tail": [2, 12, 12, 30],
                "frontLeg": [28, 21, 34, 40],
                "hindLeg": [12, 21, 18, 40],
            },
            front_size=(48, 42),
            side_size=(48, 42),
            front_ground_y=40,
            side_ground_y=40,
        )


def _boxes_shifted(dx):
    return {
        "front": {
            "head": [10 + dx, 4, 30 + dx, 20],
            "tail": [32 + dx, 15, 40 + dx, 31],
            "leftFrontLeg": [12 + dx, 20, 18 + dx, 40],
            "rightFrontLeg": [22 + dx, 20, 28 + dx, 40],
        },
        "side": {
            "head": [25 + dx, 5, 42 + dx, 21],
            "tail": [2 + dx, 12, 12 + dx, 30],
            "frontLeg": [28 + dx, 21, 34 + dx, 40],
            "hindLeg": [12 + dx, 21, 18 + dx, 40],
        },
    }


def test_tail_pivot_survives_off_centre_sprite():
    # sprite pushed far right of a wide canvas: the body side of the tail box
    # must still be judged against the head, not the canvas centre
    shifted = _boxes_shifted(200)
    rig = build_rig(
        front_boxes=shifted["front"],
        side_boxes=shifted["side"],
        front_size=(480, 42),
        side_size=(480, 42),
        front_ground_y=40,
        side_ground_y=40,
        side_facing="right",
    )
    assert rig["front"]["pivots"]["tail"][0] == 232  # body-side edge, not 240
    assert rig["side"]["pivots"]["tail"][0] == 212


def _valid_rig():
    return build_rig(
        front_boxes=_boxes_shifted(0)["front"],
        side_boxes=_boxes_shifted(0)["side"],
        front_size=(48, 42),
        side_size=(48, 42),
        front_ground_y=40,
        side_ground_y=40,
        side_facing="right",
    )


def test_validate_rig_rejects_extra_fields_and_float_version():
    from tools.rig_pipeline.rig import validate_rig

    sizes = {"front": (48, 42), "side": (48, 42)}
    validate_rig(_valid_rig(), sizes)

    extra = dict(_valid_rig())
    extra["comment"] = "not allowed"
    with pytest.raises(ValueError):
        validate_rig(extra, sizes)

    floaty = dict(_valid_rig())
    floaty["rigVersion"] = 1.0
    with pytest.raises(ValueError):
        validate_rig(floaty, sizes)

    extra_front = dict(_valid_rig())
    extra_front["front"] = dict(extra_front["front"], note="nope")
    with pytest.raises(ValueError):
        validate_rig(extra_front, sizes)
