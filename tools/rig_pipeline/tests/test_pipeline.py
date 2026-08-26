import json
import zipfile

from PIL import Image, ImageDraw

from tools.rig_pipeline.pipeline import PipelineConfig, run_pipeline


class FakeGeminiClient:
    def __init__(self):
        self.generated = []

    def generate_image(self, *, prompt, reference_images):
        self.generated.append((prompt, tuple(reference_images)))
        image = Image.new("RGB", (64, 64), (245, 230, 205))
        draw = ImageDraw.Draw(image)
        draw.rectangle((17, 8, 46, 60), fill=(110, 65, 40))
        return image

    def detect_rig(self, *, front_image, side_image):
        return {
            "species": "cat",
            "front": {
                "boxes": {
                    "head": [17, 8, 47, 30],
                    "tail": [43, 30, 55, 50],
                    "leftFrontLeg": [20, 30, 29, 61],
                    "rightFrontLeg": [35, 30, 44, 61],
                }
            },
            "side": {
                "facing": "right",
                "boxes": {
                    "head": [38, 8, 55, 29],
                    "tail": [8, 25, 20, 45],
                    "frontLeg": [39, 29, 47, 61],
                    "hindLeg": [20, 29, 28, 61],
                },
            },
        }


def test_pipeline_uses_mocked_network_and_builds_pack_and_qa(tmp_path):
    photo = tmp_path / "identity.png"
    Image.new("RGB", (20, 20), "gray").save(photo)
    output = tmp_path / "miso.pettodopet"
    qa_output = tmp_path / "miso.qa.png"
    client = FakeGeminiClient()
    config = PipelineConfig(
        photos=(photo,),
        text_only=None,
        pet_id="miso",
        display_name="Miso",
        species="cat",
        treat_name="fish",
        treat_emoji="🐟",
        output=output,
        qa_output=qa_output,
        best_of=2,
    )

    run_pipeline(config, client=client, progress=lambda _: None)

    assert output.is_file()
    assert qa_output.is_file()
    assert len(client.generated) == 8
    # Closed-eye generation receives the chosen open-eye canonical image last.
    assert client.generated[2][1][-1].name == "front-open.png"
    with zipfile.ZipFile(output) as archive:
        pack = json.loads(archive.read("pack.json"))
        assert pack["formatVersion"] == 3
        assert pack["species"] == "cat"
        assert json.loads(archive.read("rig.json"))["side"]["facing"] == "right"


class FlakyGeminiClient(FakeGeminiClient):
    """First image call fails at content level; the rest succeed."""

    def __init__(self):
        super().__init__()
        self.calls = 0

    def generate_image(self, *, prompt, reference_images):
        from tools.rig_pipeline.gemini import GeminiError

        self.calls += 1
        if self.calls == 1:
            raise GeminiError("simulated missing image")
        return super().generate_image(prompt=prompt, reference_images=reference_images)


def test_best_of_survives_a_failed_candidate(tmp_path):
    photo = tmp_path / "identity.png"
    Image.new("RGB", (20, 20), "gray").save(photo)
    config = PipelineConfig(
        photos=(photo,),
        text_only=None,
        pet_id="miso",
        display_name="Miso",
        species="cat",
        treat_name="fish",
        treat_emoji="🐟",
        output=tmp_path / "miso.pettodopet",
        qa_output=tmp_path / "miso.qa.png",
        best_of=2,
    )
    run_pipeline(config, client=FlakyGeminiClient(), progress=lambda _: None)
    assert (tmp_path / "miso.pettodopet").is_file()


class ShiftyClosedClient(FakeGeminiClient):
    """front-closed candidates come back in a different pose (silhouette shift)."""

    def __init__(self):
        super().__init__()
        self.calls = 0

    def generate_image(self, *, prompt, reference_images):
        self.calls += 1
        if self.calls in (3, 4):  # the two front-closed candidates
            image = Image.new("RGB", (64, 64), (245, 230, 205))
            ImageDraw.Draw(image).rectangle((2, 30, 30, 62), fill=(110, 65, 40))
            return image
        return super().generate_image(prompt=prompt, reference_images=reference_images)


def test_closed_eye_pose_gate_rejects_silhouette_drift(tmp_path):
    import pytest

    photo = tmp_path / "identity.png"
    Image.new("RGB", (20, 20), "gray").save(photo)
    config = PipelineConfig(
        photos=(photo,),
        text_only=None,
        pet_id="miso",
        display_name="Miso",
        species="cat",
        treat_name="fish",
        treat_emoji="🐟",
        output=tmp_path / "miso.pettodopet",
        qa_output=tmp_path / "miso.qa.png",
        best_of=2,
    )
    with pytest.raises(ValueError, match="silhouette IoU"):
        run_pipeline(config, client=ShiftyClosedClient(), progress=lambda _: None)


class DeadTransportClient(FakeGeminiClient):
    """Every image call fails at transport level; count the attempts."""

    def __init__(self):
        super().__init__()
        self.calls = 0

    def generate_image(self, *, prompt, reference_images):
        from tools.rig_pipeline.gemini import GeminiTransportError

        self.calls += 1
        raise GeminiTransportError("network down")


def test_transport_failure_is_not_amplified_by_best_of(tmp_path):
    import pytest
    from tools.rig_pipeline.gemini import GeminiTransportError

    photo = tmp_path / "identity.png"
    Image.new("RGB", (20, 20), "gray").save(photo)
    config = PipelineConfig(
        photos=(photo,),
        text_only=None,
        pet_id="miso",
        display_name="Miso",
        species="cat",
        treat_name="fish",
        treat_emoji="🐟",
        output=tmp_path / "miso.pettodopet",
        qa_output=tmp_path / "miso.qa.png",
        best_of=2,
    )
    client = DeadTransportClient()
    with pytest.raises(GeminiTransportError):
        run_pipeline(config, client=client, progress=lambda _: None)
    assert client.calls == 1  # no best-of resampling on transport death


def test_anchor_references_lead_and_are_labelled(tmp_path):
    photo = tmp_path / "identity.png"
    pose_ref = tmp_path / "pose.png"
    style_ref = tmp_path / "style.png"
    for path in (photo, pose_ref, style_ref):
        Image.new("RGB", (20, 20), "gray").save(path)
    client = FakeGeminiClient()
    config = PipelineConfig(
        photos=(photo,),
        text_only=None,
        pet_id="miso",
        display_name="Miso",
        species="cat",
        treat_name="fish",
        treat_emoji="🐟",
        output=tmp_path / "miso.pettodopet",
        qa_output=tmp_path / "miso.qa.png",
        pose_ref=pose_ref,
        style_ref=style_ref,
        best_of=1,
    )
    run_pipeline(config, client=client, progress=lambda _: None)

    front_prompt, front_refs = client.generated[0]
    assert front_refs[0].name == "pose.png"
    assert front_refs[1].name == "style.png"
    assert "pose reference" in front_prompt
    assert "style reference" in front_prompt
    sleep_prompt, sleep_refs = client.generated[2]
    assert sleep_refs[0].name == "style.png"  # pose anchor is front-only
    assert "pose reference" not in sleep_prompt


def test_degenerate_tail_box_fails_the_pose_contract(tmp_path):
    import pytest

    class TuckedTailClient(FakeGeminiClient):
        def detect_rig(self, *, front_image, side_image):
            rig = super().detect_rig(front_image=front_image, side_image=side_image)
            rig["front"]["boxes"]["tail"] = [43, 30, 44, 31]  # hidden tail
            return rig

    photo = tmp_path / "identity.png"
    Image.new("RGB", (20, 20), "gray").save(photo)
    config = PipelineConfig(
        photos=(photo,),
        text_only=None,
        pet_id="miso",
        display_name="Miso",
        species="cat",
        treat_name="fish",
        treat_emoji="🐟",
        output=tmp_path / "miso.pettodopet",
        qa_output=tmp_path / "miso.qa.png",
        best_of=1,
    )
    with pytest.raises(ValueError, match="tail looks hidden"):
        run_pipeline(config, client=TuckedTailClient(), progress=lambda _: None)
