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

## v0.2.0 — import and extraction
- [x] Before/after preview and sensitivity control for Smart Crop.
- [x] Selection by rectangle or lasso on imported image, saved as transparent layer.
- [x] Explicit approval before import, including preview of Split Sheet output.
- [ ] Validate on Android through GitHub Actions and device testing.

## v0.2.1 — Smart Crop corrections
- [x] Correct white-pixel alpha handling at maximum sensitivity.
- [x] Use a checkerboard to show actual transparency in the preview.
- [x] Add direct selection shortcut for screenshot imports.
- [ ] Verify on physical Android device after successful build.
- Complex screenshots still require rectangle/lasso selection around desired artwork; no AI segmentation yet.

## v0.3.0 — select and detect multiple artwork pieces
- [x] After drawing a rectangle/lasso around artwork, optionally detect separate regions inside it.
- [x] Preview detected pieces and select exactly which ones to add as layers.
- [x] Add a test excluding a screenshot header from the manually selected region.
- [ ] Validate the GitHub Actions build and actual Android output.
- No semantic AI segmentation: close/touching motifs may still merge; intricate backgrounds may need manual selection.

## v0.4.0 — reversible erase tool
- [x] Dedicated touch eraser for selected, unlocked image layer.
- [x] Adjustable round brush, undo last stroke, and Restore all.
- [x] Preserve the original layer bitmap; save reversible mask strokes in project JSON.
- [x] Regenerate masked layers on reopen, undo/redo, duplicate and PNG export.
- [x] Unit tests for mask rendering and project compatibility.
- [ ] Verify Flutter compilation, Android device behavior, and build workflow.
- This is a raster eraser, not a vector-editing or smart object-removal tool.

## v0.5.0 — canvas precision controls
- [x] Separate Edit and Navigate modes to avoid competing layer gestures.
- [x] Navigate with pinch zoom (up to 8x) and pan; reset zoom button.
- [x] Snap selected layers to canvas center within a 12 px tolerance.
- [x] Show alignment guidelines during snapping; guides excluded from PNG export.
- [x] Nudge selected layers by 1 px or 10 px; center a layer precisely.
- [x] Cycle to an overlapping layer beneath the current selection, with Layers list fallback.
- [x] Unit tests for center snap geometry.
- [ ] Verify Android build, multi-touch behavior, and on-device export.
- Viewport zoom is not saved as part of the project and does not change exported image resolution.

## v0.6.0 — tattoo-specific stencil preparation
- [x] Add optional grayscale-to-black stencil threshold processing with preview.
- [x] Adjustable threshold and opt-in removal of isolated speckle pixels.
- [x] Export stencil PNG against white or transparent background.
- [x] Export normal composition PNG against white or transparent background.
- [x] Derived stencil is not a destructive modification to editable project layers.
- [x] Add image processing unit tests for alpha, ink threshold and noise cleanup.
- [ ] Verify compilation, workflow success and on-device UI/export.
- [ ] Physical size and DPI control, transfer-printer calibration and high-fidelity line cleanup remain future work.
- Stencil preview is for design review only, not a validated ready-to-transfer tattoo stencil.
