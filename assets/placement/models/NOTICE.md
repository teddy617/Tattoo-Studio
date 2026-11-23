# Detailed mannequin asset attribution

The model in `makehuman_cc0.obj` is derived from the MakeHuman hm08 base mesh.

- Original project: https://github.com/makehumancommunity/makehuman
- Original file: `makehuman/data/3dobjs/base.obj`
- Original blob SHA: `d26635e9326e3cca30778fd7b9c00062b03cce09`
- Source header: "This asset was explicitly released as CC0 in september 2020."
- Copyright holders listed by the original file: Data Collection AB, Joel Palmius, Jonas Hauquier (2020).
- License: CC0 1.0 Universal (public-domain dedication).

Transformation: vertex coordinates reduced to three decimal places and texture coordinates removed. The model was further filtered to the largest connected surface component (13,380 vertices, 13,378 polygon faces), excluding 153 disconnected auxiliary components that produced visual artifacts; face indices were remapped. The app builds surface normals and approximate body-region UV coordinates at runtime.

No source models are downloaded at runtime. This is a generic, unrigged human shape, not an individual's anatomy or medical measurement reference.

The app's existing procedural mannequin remains a fallback on devices where the detailed body mesh cannot be initialized.
