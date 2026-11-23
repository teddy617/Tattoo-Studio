import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Prepare an imported tattoo for 3D WebGL without altering the source asset.
/// Keeps transparent pixels transparent and bounds mobile texture memory.
Uint8List prepareTattooTexture(Uint8List bytes) {
  final original = img.decodeImage(bytes);
  if (original == null) throw const FormatException('Unsupported image');
  final oriented = img.bakeOrientation(original);
  final resized = oriented.width > 1200 || oriented.height > 1200
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 1200 : null,
          height: oriented.height > oriented.width ? 1200 : null,
        )
      : oriented;
  return Uint8List.fromList(img.encodePng(resized));
}
