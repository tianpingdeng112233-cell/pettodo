# Rig pipeline CLI

Build a PetTodo rig pack v3 from one to three pet photos:

```sh
python3 -m pip install -r tools/rig_pipeline/requirements-dev.txt
python3 -m tools.rig_pipeline pet-front.jpg pet-side.jpg \
  --id miso --name Miso --species cat --output build/miso.pettodopet
```

Or build a preset from text only:

```sh
python3 -m tools.rig_pipeline --text-only "a red shiba inu with a cream muzzle" \
  --id red-shiba --name "Red Shiba" --species dog
```

`--pose-note "..."` appends a free-text emphasis to every pose prompt — use it
to pin details the identity references alone cannot hold (a breed's true tail
carriage, a strict no-white-markings coat). The base prompt deliberately defers
tail length and carriage to the pet's own references.

The live command reads the Gemini API key at runtime using
`security find-generic-password -s gemini-api-key -w`. The key is held in memory
and is never written to a file. Use `--dry-run` to validate input and inspect the
full execution plan without network or Keychain access.

The `.pettodopet` output contains only `pack.json`, `rig.json`, and the four
canonical RGBA PNGs at the archive root. The adjacent `.qa.png` contact sheet is
an inspection artifact and is not placed in the pack.

Run the isolated tests with:

```sh
python3 -m pytest tools/rig_pipeline/tests -q
```
