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
- [ ] 3D placement previews on a freely turnable model with tattoo geometry conforming to its surface (see 3D_PLACEMENT_PLAN.md)

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

## v0.7.0 — actual artwork physical print width
- [x] Specify intended visible-artwork width in inches or centimeters (0.5–8 in).
- [x] Select 150 or 300 DPI and see the calculated output pixel width.
- [x] Automatically trim transparent margins before sizing.
- [x] Export opaque-white or transparent PNG while retaining image aspect ratio.
- [x] Add PNG pHYs physical resolution metadata and preserve it on stencil exports.
- [x] Add unit tests for crop-to-artwork sizing and PNG encoding.
- [ ] Verify GitHub Actions Android build and real printer behavior.
- Print at 100% / Actual Size and disable scaling. Some print apps ignore PNG DPI metadata.
- Enlarging a low-resolution image does not recover lost line detail.
- Current PNG export is not a professionally calibrated transfer-stencil workflow.

## v0.8 — planned 3D tattoo placement prototype
- [x] Approve separate, offline 3D Placement Studio architecture (Flutter + bundled Three.js WebView).
- [x] Define proof-of-concept stages and acceptance criteria in [3D_PLACEMENT_PLAN.md](3D_PLACEMENT_PLAN.md).
- [x] Add offline turnable forearm proxy and bundled Three.js renderer source (Android behavior unverified).
- [x] Implement surface-conforming tattoo texture mapping on a 3D forearm mesh (requires on-device visual verification).
- [x] Add Orbit/Place modes, tap-to-anchor, scale, rotation, opacity and projection-depth controls.
- [x] Add per-project placement autosave/reload independent from design layers.
- [x] User confirmed the standalone forearm WebGL viewer loads on Android and displays a curved tattoo, with placement and controls visible in screenshot (2026-11-23).
- [ ] Verify 180-degree rotation, accuracy of seam wrapping, and save/reopen on device.
- [x] Add stylized offline full-body procedural mannequin and selectable regions with closer camera views (source implemented, requires Android testing).
- Source version v0.8.1, pending Android build and device verification of full-body view.
- The procedural forearm is illustrative only. No anatomical accuracy, full-body rig, custom contour painting, or calibrated tattoo dimensions yet.

### v0.8 Android viewer loading correction
- Initial on-device screenshot showed `net::ERR_FAILED` and a persistent spinner after Three.js module loading.
- Replaced the module-based viewer entry point with standalone WebGL and inline shaders to avoid local-file ES-module loading failures on Android WebView.
- Kept orbit/place modes, alpha tattoo texture mapping, size/rotation/opacity/wrap controls, and saved surface position.
- Added a visible retry path when initialization fails; physical-device retest is required before treating this as fixed.

## v0.8.1 — full-body placement prototype (pending device validation)
- [x] Render full procedural mannequin (head, torso, pelvis, arms, hands, thighs, calves, feet).
- [x] Choose whole-body overview or specific regions, including left/right limbs, chest, back and abdomen.
- [x] Maintain selected tattoo location while viewing whole body, and zoom toward chosen region.
- [x] Improve touch placement using mesh-triangle barycentric interpolation and smooth position transitions.
- [x] Preserve tattoo alpha and wrap to the selected mesh with independent opacity, rotation, scale and wrap width.
- [x] Save chosen body part and normalized surface coordinates per project (legacy forearm saves supported approximately).
- [x] Stay offline using the working single-file WebGL viewer; no module imports or network.
- [ ] Compile in GitHub Actions and confirm full-body display, gesture movement, side views and restoration on Android.
- [ ] Upgrade to properly licensed realistic anatomical GLB meshes after correctness and performance are confirmed.
- [ ] Support seamless ink across multiple body meshes, articulated posing and physical body-measurement calibration.
- Important: The new mannequin is a *stylized segmented approximation*, not a realistic human anatomy scan. Tattoo wrap does not yet cross body-part seams.

## v0.9.0 — detailed anatomy and multi-tattoo placement (source implemented; device test pending)
- [x] Bundle an offline MakeHuman hm08 CC0 real human surface mesh with file-specific provenance in `assets/placement/models/NOTICE.md`.
- [x] Replace simplified mannequin rendering with anatomical mesh where supported; retain Basic fallback.
- [x] Segment mesh into selectable anatomical surface regions using approximate body-space bounds.
- [x] Render multiple independent alpha PNG textures simultaneously, depth-tested against other body parts.
- [x] Add tattoo from device gallery or any current project layer and cap at 12 for initial GPU memory protection.
- [x] Select/remove individual tattoos, change size, rotation, opacity, wrapping width and visibility.
- [x] Save per-tattoo image assets and transforms in local project storage independently from editable 2D layers.
- [x] Add scrollable placement settings while keeping sufficient 3D viewing area.
- [x] Add image conversion tests for alpha preservation, input validation, and maximum image dimensions.
- [ ] Compile with GitHub Actions; check model load and 3D placement on physical Android.
- [ ] Verify reopening project restores every tattoo and body location, including older single-tattoo saves.
- [ ] Add finer body-region boundaries, seamless cross-region ink projection, calibrated physical dimensions, and multiple realistic body shapes.
- **Limitations:** Anatomical model is a generic static A-pose, not rigged; selection regions and generated UVs are approximate. Fine tattoos may distort at region boundaries. Current overlay stacking is simple draw order, not skin-physics simulation.

## v0.9.1 — surface projection and approximate tattoo sizing (source implemented; Android test pending)
- [x] Replace region-specific UV stamping with world-space tangent-plane projection anchored on the actual chosen mesh surface.
- [x] Permit tattoos to span adjacent mesh-region boundaries where geometry, depth and facing angle allow; clamp back-face bleeding.
- [x] Store per-tattoo surface position and normal, with migration fallback for previously saved UV-only placements.
- [x] Reset the anchor to the newly selected body part rather than leaving it on the last limb.
- [x] Add a per-tattoo width control in centimeters, stored independently for each design.
- [x] Smooth on-screen movement between surface anchors and cache projected mesh vertices to reduce touch lag.
- [x] Keep independent tattoo layering, visibility and local per-project persistence.
- [ ] Verify actual WebGL shader compilation, wrap appearance, camera motion and tattoo persistence on Android.
- [ ] Calibrate physical dimensions to the mannequin's actual height and measurements; presently assumes an illustrative 170 cm body.
- [ ] Replace tangent-plane projection with geodesic/UV or surface-patch method for strong curvature and complex joint wraps.
- This is *not* accurate transfer-stencil sizing: the preview width is approximate and the 2D print export remains separately calibrated.

## v0.9.2 — Android 3D error and distorted anatomy corrections
- [x] Remove undeclared `lastX` / `lastY` assignments that caused a JavaScript ReferenceError on pointer-down.
- [x] Filter MakeHuman mesh to the main connected human skin surface (13,380 vertices; 13,378 quad faces), excluding 153 disconnected non-skin/helper components.
- [x] Record source, CC0 provenance, filtering and face-index remapping in the model NOTICE.
- [x] Version placement surface anchors and approximate reproject legacy anchors onto the corrected surface on reopen.
- [x] Invalidate and reproject placement anchors when switching Detailed / Basic mesh.
- [ ] Test latest Android build on device: smooth rotations, tattoo layer movement, detailed model appearance, saved multi-tattoo preview and old-project migration.
- This is still a generic body mesh, with approximate surface region boundaries and tattoo widths; placement is not an anatomical scan or clinical measurement.

## v0.9.3 — smoother placement, edge blend and gesture stability
- [x] Add an edge-feather slider per tattoo, persisted with its independent placement.
- [x] Smooth the tattoo's surface orientation during movement to reduce twisting on sloping/curved anatomy.
- [x] Keep a moving tattoo on its selected surface region during dragging, while allowing tap-to-reposition.
- [x] Add directional precision nudges and a Fit view camera control.
- [x] Fade tattoo projection near texture edges, high-curvature facing limits and projection depth boundaries.
- [x] Cull distant body meshes during each tattoo render pass to reduce mobile GPU work.
- [x] Add a dependency-free viewer smoke test (anatomical model, gesture handling, multi-tattoo restoration) and run it before Flutter tests in GitHub Actions.
- [ ] Validate on Android device: shader appearance, edge blending, rotation, nudge response and 3D frame rate.
- [ ] Replace tangent-plane stamping with surface-aware geodesic deformation for highly curved shoulders/joints; current feathering reduces harsh cutoffs but is not true skin-wrapped deformation.

## v0.9.4 — local curvature compensation for surface wrapping
- [x] Add shader-based arc-length correction from changes in 3D surface normals, reducing tattoo compression on curved limbs and shoulders.
- [x] Per-tattoo Curve conform slider (0–100%), retaining the prior planar look when set to zero.
- [x] Save curve-conform strength with each tattoo alongside opacity, placement, edge softness and width.
- [x] Expand offline placement smoke checks for shader presence and multi-tattoo curvature restoration.
- [ ] Confirm curvature strength, seam appearance and GPU performance on physical Android devices; shader compilation cannot be verified by JS smoke tests alone.
- [ ] Implement true geodesic/mesh-unwrapped tattoo charts for highly curved shoulders and joints. This version applies an approximate normal-based correction, **not** physically accurate geodesic unwrap.
