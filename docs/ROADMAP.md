# Tattoo Studio development roadmap

## Product principles
- Utility-first: the editor should be usable without signing up or paying.
- Local-first: keep editable source layers and projects on the device.
- Non-destructive where practical: do not flatten the project when exporting.
- Android-first Flutter codebase, iOS-ready architecture.
- No AI image generation or API costs during initial development.

## Current prototype (v0.1.0)
- [x] Projects list, new project, rename, deletion, local file persistence
- [x] Multi-image imports
- [x] Automatic white-background removal and whitespace trim
- [x] Coarse connected-region detection for separated flash-sheet motifs
- [x] Import unchanged for complex/colored backgrounds
- [x] Independent layers with drag, pinch resize, rotation, mirror
- [x] Layer visibility, lock, duplicate, delete, front/back ordering
- [x] Undo and redo for editing history
- [x] PNG export using native share sheet
- [x] Android debug build workflow
- [ ] On-device Android build verification; needs first GitHub Actions run

## Phase 1.1 — precision editing
- [ ] Freehand lasso and rectangular crop tools (manual region extraction)
- [ ] Eraser and non-destructive layer masks
- [ ] Region merging/splitting with adjustable extraction sensitivity
- [ ] Canvas zoom/pan, snap guides, alignment and precise transform controls
- [ ] Undo stack persistence and autosave recovery after unexpected termination
- [ ] Export transparency and physical sizing for stencil print workflows

## Phase 1.2 — tattoo-specific tools
- [ ] Fine line/blackwork cleanup, stencil preview, line weight controls
- [ ] Style reference collection and user-created templates
- [ ] Brush drawing and editable text/lettering
- [ ] Accurate measurements in inches/cm, size presets, 300 DPI export
- [ ] Placement previews with uploaded body photographs

## Phase 2 — optional intelligence
- [ ] On-device segmentation model for textured backgrounds
- [ ] Selection-aware object removal or reconstruction
- [ ] Optional cloud AI generation later, behind explicit opt-in and spending controls

## Technical limits of v0.1.0
- Smart extraction is classical image processing, not AI segmentation.
- It works best on plain white or transparent backgrounds; complex backgrounds
  are usually kept intact. White regions *inside* artwork may also be cleared.
- Split Sheet groups nearby strokes and may merge or fragment illustrations.
- Each import becomes one rectangular raster layer with transparent pixels;
  vector-level control of the individual curves is not implemented yet.
- Imported artwork is downscaled to 2400 px along its longest side before
  processing to reduce memory usage. Keep source originals separately.
- A flat PNG export is not a stencil guarantee; an artist should check actual
  line thickness, contrast and placement before tattooing.
- The app saves only to local app storage. Removing the app can delete projects.
