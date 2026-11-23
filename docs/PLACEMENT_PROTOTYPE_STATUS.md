# 3D placement prototype — initial implementation

**Status:** source committed; Android APK compilation and device behavior not verified. Application version remains v0.7 while this experimental prototype is validated.

## Implemented
- Editor menu opens a new 3D Placement prototype screen.
- Bundled offline HTML/WebGL forearm proxy; drag to turn, experimental pinch zoom.
- Reduced-size transparent current design is trimmed and loaded from Flutter into the embedded viewer locally.
- Tattoo is texture-mapped onto the curved limb mesh; it is not a flat screen overlay.
- Size, rotation, opacity sliders and reset; Android external navigation is blocked.

## Still required before calling this complete
- Android build and on-device WebGL verification.
- True raycast-anchor placement and projected decal geometry (the current UV texture mapping is a preliminary proof only).
- Tangent-plane movement, contour/wrap, projection depth, position save/reopen.
- Realistic, appropriately licensed GLB anatomy after the geometric proof.
- Real-world placement accuracy and body proportions are not guaranteed.

The original plan is in [3D_PLACEMENT_PLAN.md](3D_PLACEMENT_PLAN.md).
