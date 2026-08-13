# Proposal 009 — Smoother pet animation

Status: **awaiting decision** (David chose "change the paradigm" on 2026-08-13;
this proposal picks the sub-route that survives our constraints)

## The problem, measured

`idle` is **6 frames** played at **8 fps** with a hard cut between frames
(`drawImageRect`, `FilterQuality.none`). Each frame holds for 125 ms. Pixel-art
games get away with 8 fps because the style hides it; our pet is photoreal
rendering, where the eye expects motion continuity. Raising the frame rate alone
does not help: 6 frames at 24 fps loops in 0.25 s and reads as jitter instead of
choppiness.

Separately, each cell is 192×208 shown at 150×162 pt — on a @3x screen that is
an upscale to 450×486 px through a nearest-neighbour filter. That is a one-line
image-quality bug independent of the animation question.

## Hard constraints (these decide the answer)

1. **The art pipeline's output shape is fixed.** `hatch-pet` produces a
   Codex-compatible **v2 8×11 atlas** (9 animation rows + 16 look directions).
   That format is shared with the Codex pet ecosystem, not ours to redefine.
2. **Every user's own pet goes through that pipeline.** Own-pet hatching became
   a core feature on 08-12. Any per-pet manual step multiplies by every user.
3. **Frames are generated independently.** Row frames are sampled separately by
   `$imagegen`, so neighbouring frames carry pose/lighting drift. More frames
   would not automatically mean smoother motion — it can turn choppy into shaky.
4. Zero-punishment and "the pet is never hurt" apply to motion too: nothing
   twitchy, nothing that reads as distress.

## Sub-routes considered

### C1 — Rive (or Live2D-style rigging)
Designer rigs the pet in an editor, app plays a `.riv` state machine. Best
expressiveness and the designer iterates without code.
**Rejected**: rigging is per-pet manual work. Concierge already costs David one
`hatch-pet` run per user; adding a rig per user makes own-pet hatching
unscalable — it would trade our newest core feature for smoothness.

### C2 — Layered sprite + transforms
Cut the pet into body / head / ears / eyes / tail layers, drive each with
`Transform` and sine motion.
**Rejected for now**: `hatch-pet` does not emit layers. Producing them means
either a designer cutting every pet by hand (same scaling problem as C1) or
adding a segmentation stage to the pipeline (new failure mode, new QA surface).

### C3 — Mesh deformation of a single frame ✅ recommended
Take one clean cut-out frame (the atlas is already chroma-keyed), lay a vertex
grid over it, and drive the vertices with sine functions via
`Canvas.drawVertices`. Breathing = vertical scale wave; idle sway = low-frequency
horizontal shear; look-at = local displacement toward the gaze. Continuous by
construction, runs at whatever frame rate the display gives, and costs **zero
pipeline change and zero new art** — it consumes the atlas we already ship.

## Recommended: hybrid renderer

- **Resting states** (`idle`, `waiting`, and the 16 look directions) — render one
  frame through the deforming mesh. This is what the user stares at for 95% of
  the session, and it is where "choppy" is currently most visible.
- **Event actions** (`jumping`, `waving`, `review`) — keep the existing
  frame-by-frame atlas playback. These are short, deliberately cartoonish beats;
  frame-stepping reads as snappy there rather than broken.
- **Blinking** stays a texture swap: the idle row already contains blink frames,
  so occasionally swapping the mesh's source cell keeps eyes alive without
  fighting the deformation.
- Fix `FilterQuality` for the upscale regardless of which route we take.

## What this costs

New `_MeshSpritePainter` beside the existing painter, a small parameter set
(grid density, breathing amplitude/period, sway, gaze displacement), and a
switch in `PetSprite` choosing mesh vs frame playback per state. Domain,
persistence, and the pipeline are untouched. No new screens.

## Risks

- **Jelly look.** Over-deformation makes a photoreal dog feel rubbery. Amplitudes
  must stay small; this needs eyes-on tuning, not a spec value.
- **Anchor drift.** Feet must stay planted — the bottom row of vertices should be
  pinned or the pet appears to float.
- Both are tuning problems, visible immediately in a prototype.

## Open for David

1. Prototype first, or spec first? A single throwaway page comparing current
   playback against the mesh, on Choco, would settle the jelly question in one
   look.
2. Designer involvement: no new art needed, but breathing rhythm and amplitude
   are a design call — worth a pass once the prototype exists.
