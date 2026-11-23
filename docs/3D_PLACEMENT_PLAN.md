# Tattoo Studio — 3D Placement Studio development plan

Status: approved direction, **planning only**. Current application remains v0.7.0.
Priority: prove that a transparent tattoo image conforms to a rotating 3D limb, rather than floating as a flat image over the screen.

## Product requirements

- Local-first: no account, camera, upload, hosted 3D service, paid API or AI required.
- Select a supported body part; orbit and zoom an anatomical mannequin.
- Place the current transparent composition on the chosen body surface.
- Project ink onto curved geometry so the image visibly follows the limb when viewed from the side.
- Move along the surface, rotate in the local tangent plane, scale proportionally, mirror, change opacity, and adjust safe wrap/projection depth.
- Switch between stencil and artwork preview without editing the source project.
- Save/reopen placement settings separately from the editor layers.
- Clear limitations: a generic model is not a scan of the user's anatomy and cannot determine exact skin distortion or fitting.

## Architecture decision

Flutter remains the native application shell and saves project data. A bundled offline Three.js/WebGL viewer renders the 3D placement scene in a Flutter WebView. This has a smaller initial integration surface than embedding Unity.

- Flutter: project identity, PNG extraction, size values, navigation, persistence, export and error states.
- WebView bridge: versioned JSON messages with allowlisted methods. JS receives the body-part selection, PNG texture bytes (or isolated local resource), and placement state; it returns updates and selection events. No internet or arbitrary URL navigation required.
- Three.js: static GLB model loading, orbit camera, raycast selection, local tangent frame, projected decal geometry, mesh/textures and lighting.
- Assets: package optimised, properly licensed **static** GLB geometry locally. Do not ship an unverified third-party anatomy model. A simple procedural cylinder/limb proxy is enough for the initial projection test.
- Persist JSON to the existing local project directory; design source and original layer assets remain untouched.
- Keep renderer implementation behind a placement adapter for a future native renderer migration if Android WebView performance proves inadequate.

Potential integration: official `webview_flutter` on Android/iOS. Three.js `DecalGeometry` provides a baseline projector onto a mesh. It is not equivalent to anatomically accurate deformation and can clip or distort on sharp curves, seams, or complex mesh boundaries.

## Versioned milestones

### v0.8.0 — minimum proof of concept
1. Add `lib/screens/placement_screen.dart` with 3D viewing region and a compact mode bar (Orbit / Place).
2. Add bundled offline viewer assets under `assets/placement/` with a simple anatomical forearm proxy (or generated tapered tube).
3. Show the model in 3D; freely rotate via one finger and zoom via pinch.
4. Load the current design as an alpha PNG texture, raycast a tap to find the placement position and normal, and create a conforming projected decal.
5. Provide size, orientation, opacity, and projection depth controls with immediate update; allow resetting placement.
6. Save/load a placement record independent of editable layers.
7. Validate Android APK and real-device gestures before adding more features.

**Acceptance criteria:** Rotate the limb 180 degrees and the projected tattoo remains anchored on its skin geometry; the image visibly bends around the near edge. Reopening the same project restores placement without affecting its layers. No network requests are necessary.

### v0.8.1 — robust wrap and interaction
1. Investigate texture stretching on rounded limbs, near-seams, grazing angles and back-face projection. Constrain placement to intended surface region.
2. Implement tangent-plane movement anchored by raycasting and surface normals; separate Orbit and Place gestures to avoid conflicts.
3. Add contour/wrap extent and edge softness where feasible; explain that controls tune projection and do not simulate biological skin deformation.
4. Add undo/reset for placement edits and unit tests for state serialization and value clamping.
5. Profile real Android WebView/WebGL devices; simplify meshes and texture resolution if responsiveness suffers.

### v0.9 — expand supported anatomy
1. Add upper arm, calf and chest meshes, then upper back if performance permits.
2. Offer left/right side and a few general body proportions, clearly marked as illustrative.
3. Make local scale approximate real inches/cm by defining calibrated mesh dimensions.
4. Add reusable framing/camera presets and optional screenshot export, separately from print-ready stencil export.

## Initial UI flow

Editor -> **3D Preview** -> choose body part -> Orbit to see the body -> Place to tap skin -> adjust width/rotation/wrap/opacity -> Save Preview -> return to Editor.

The current composition PNG must be rendered on transparency, without the editor's white page. Use a quality appropriate to WebGL texture memory; preserve the high-resolution artwork separately.

## Data design

Example persisted record (illustrative; refine before code):

```json
{
  "schemaVersion": 1,
  "projectId": "project-id",
  "bodyPart": "forearm",
  "modelVersion": "forearm-v1",
  "anchor": {
    "position": [0.0, 0.0, 0.0],
    "normal": [0.0, 0.0, 1.0]
  },
  "orientationDegrees": 0.0,
  "widthCentimeters": 8.0,
  "projectionDepth": 0.4,
  "opacity": 0.85,
  "mirrored": false,
  "previewMode": "artwork"
}
```

Store placement in model-local coordinates and include modelVersion so transforms can be migrated if mesh geometry changes. Position+normal alone may drift after topology/model updates; for future robust anchoring, record mesh region and triangle/barycentric coordinates where practical. Normalised size must map consistently to model dimensions.

## Files/modules planned

- `lib/screens/placement_screen.dart` — Flutter entry point and controls.
- `lib/models/placement_state.dart` — bounded, JSON-serializable placement state.
- `lib/services/placement_repository.dart` — saves placement JSON without changing design project's schema.
- `lib/services/placement_bridge.dart` — typed message contract between Dart and JS.
- `assets/placement/viewer.html` — offline WebGL host.
- `assets/placement/viewer.js` — renderer and hit testing.
- `assets/placement/vendor/` — bundled/pinned Three.js build/addons, including licenses.
- `assets/placement/models/` — licensed GLB models only once validated.
- `test/placement_state_test.dart` — serialization, bounds and migration behavior.

## Critical risks and stop conditions

- **WebView compatibility:** verify WebGL works in the actual Android debug APK before building full UI.
- **Real wrap vs fake wrap:** projected mesh geometry must stick to the target skin surface as the camera rotates. A floating planar overlay is not acceptable.
- **Surface distortions:** a single decal projection can shear, cut off and project onto unwanted rear-facing geometry. Start with forearm and test these limits, then consider UV-space mapping or patch-based projection if needed.
- **Model licensing:** avoid external meshes without proven redistribution rights.
- **Performance:** be conscious of WebGL context loss, GPU memory, old Android devices and very large tattoo PNGs.
- **Print accuracy:** appearance on a generic mannequin is not a clinical or transfer-size guarantee. Keep printed dimensions sourced from the independent 2D export settings.
- **Animation:** v0.8 uses a manually turnable *static* 3D body part. Articulated/animated posing requires additional rigged models and dynamic decal attachment, and is deferred.

## Immediate implementation order

1. Build and test an offline WebGL forearm proxy and projected decal, entirely separate from the current editor.
2. Verify a valid Three.js bundle and PNG texture can load in WebView on Android.
3. Add Flutter navigation and the safe message bridge.
4. Add controls and persistent state.
5. Only then expand body parts, realism and contour controls.

No full-body model, photo overlay, body-scan capture, cloud service or paid API in the v0.8 scope.
