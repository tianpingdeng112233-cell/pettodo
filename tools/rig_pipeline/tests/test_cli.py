from pathlib import Path

from PIL import Image

from tools.rig_pipeline.cli import main


def _photo(path: Path):
    Image.new("RGB", (10, 10), "white").save(path)


def test_cli_requires_photos_or_text_only(capsys):
    assert main([]) == 2
    assert "provide 1–3 photos or --text-only" in capsys.readouterr().err


def test_cli_rejects_text_and_photos_together(tmp_path, capsys):
    photo = tmp_path / "pet.jpg"
    _photo(photo)
    assert main([str(photo), "--text-only", "orange cat"]) == 2
    assert "cannot be combined" in capsys.readouterr().err


def test_cli_rejects_more_than_three_photos(tmp_path, capsys):
    photos = []
    for number in range(4):
        photo = tmp_path / f"pet-{number}.png"
        _photo(photo)
        photos.append(str(photo))
    assert main(photos) == 2
    assert "at most 3 photos" in capsys.readouterr().err


def test_cli_dry_run_prints_complete_plan_without_reading_keychain(tmp_path, capsys):
    photo = tmp_path / "pet.png"
    _photo(photo)

    result = main(
        [
            str(photo),
            "--id",
            "miso",
            "--name",
            "Miso",
            "--species",
            "cat",
            "--best-of",
            "3",
            "--dry-run",
            "--output",
            str(tmp_path / "miso.pettodopet"),
        ]
    )

    output = capsys.readouterr().out
    assert result == 0
    assert "gemini-3.1-flash-image" in output
    assert "3 candidates per canonical pose" in output
    assert "front-open.png -> front-closed.png -> sleep.png -> side.png" in output
    assert "gemini-3.5-flash" in output
    assert "contact sheet" in output
    assert "miso.pettodopet" in output


def test_cli_rejects_invalid_best_of_and_retries(tmp_path, capsys):
    photo = tmp_path / "pet.jpg"
    _photo(photo)
    assert main([str(photo), "--best-of", "0"]) == 2
    assert "--best-of" in capsys.readouterr().err
    assert main([str(photo), "--retries", "-1"]) == 2
    assert "--retries" in capsys.readouterr().err
