import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class PrintOptions {
  const PrintOptions({
    this.widthInches = 4,
    this.dpi = 300,
    this.transparent = false,
  });

  final double widthInches;
  final int dpi;
  final bool transparent;

  double get widthCentimeters => widthInches * 2.54;
  int get widthPixels => (widthInches * dpi).round();
}

class PrintExport {
  /// The physical width applies to visible artwork, not the full editor page.
  /// Empty transparent margins are removed before sizing.
  static Future<Uint8List> prepare(
      Uint8List png, PrintOptions options) =>
      compute(_prepare, _PrintRequest(png, options));

  static Uint8List prepareSync(Uint8List png, PrintOptions options) =>
      _prepare(_PrintRequest(png, options));

  static Uint8List setDpi(Uint8List png, int dpi) {
    if (dpi < 72 || dpi > 1200) throw ArgumentError.value(dpi, 'dpi');
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (png.length < 33 ||
        !List.generate(8, (i) => png[i] == signature[i]).every((v) => v)) {
      throw const FormatException('Expected PNG');
    }
    final header = ByteData.sublistView(png);
    if (header.getUint32(8) != 13 ||
        String.fromCharCodes(png.sublist(12, 16)) != 'IHDR') {
      throw const FormatException('Invalid PNG header');
    }

    final parts = <int>[];
    parts.addAll(png.sublist(0, 33));
    // pHYs units are pixels per meter.
    final ppm = (dpi / 0.0254).round();
    final payload = ByteData(9)
      ..setUint32(0, ppm)
      ..setUint32(4, ppm)
      ..setUint8(8, 1);
    final data = payload.buffer.asUint8List();
    final type = [112, 72, 89, 115]; // pHYs
    final chunkBody = Uint8List.fromList([...type, ...data]);
    final chunkLength = ByteData(4)..setUint32(0, 9);
    final crcBytes = ByteData(4)..setUint32(0, _crc32(chunkBody));
    parts.addAll(chunkLength.buffer.asUint8List());
    parts.addAll(chunkBody);
    parts.addAll(crcBytes.buffer.asUint8List());

    // Skip any existing pHYs chunk to avoid conflicting print metadata.
    var offset = 33;
    while (offset + 12 <= png.length) {
      final length = header.getUint32(offset);
      final end = offset + length + 12;
      if (end > png.length) throw const FormatException('Invalid PNG chunk');
      final kind = String.fromCharCodes(png.sublist(offset + 4, offset + 8));
      if (kind != 'pHYs') parts.addAll(png.sublist(offset, end));
      offset = end;
      if (kind == 'IEND') break;
    }
    return Uint8List.fromList(parts);
  }
}

class _PrintRequest {
  const _PrintRequest(this.png, this.options);
  final Uint8List png;
  final PrintOptions options;
}

Uint8List _prepare(_PrintRequest request) {
  final options = request.options;
  if (!options.widthInches.isFinite ||
      options.widthInches < 0.5 || options.widthInches > 8 ||
      (options.dpi != 150 && options.dpi != 300)) {
    throw ArgumentError('Unsupported physical dimensions or resolution');
  }

  final original = img.decodePng(request.png);
  if (original == null) throw const FormatException('Invalid canvas PNG');
  var left = original.width;
  var top = original.height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < original.height; y++) {
    for (var x = 0; x < original.width; x++) {
      if (original.getPixel(x, y).a <= 8) continue;
      left = math.min(left, x);
      right = math.max(right, x);
      top = math.min(top, y);
      bottom = math.max(bottom, y);
    }
  }
  if (right < left) throw const FormatException('No visible artwork to export');
  final crop = img.copyCrop(original, x: left, y: top,
      width: right - left + 1, height: bottom - top + 1);
  final targetWidth = options.widthPixels;
  final targetHeight = math.max(1, (crop.height * targetWidth / crop.width).round());
  if (targetHeight > 6000) {
    throw ArgumentError('Artwork is too tall for this print width');
  }
  final resized = img.copyResize(crop, width: targetWidth,
      height: targetHeight, interpolation: img.Interpolation.linear);
  if (options.transparent) {
    return PrintExport.setDpi(
        Uint8List.fromList(img.encodePng(resized)), options.dpi);
  }

  final opaque = img.Image(width: targetWidth,
      height: targetHeight, numChannels: 4);
  for (var y = 0; y < targetHeight; y++) {
    for (var x = 0; x < targetWidth; x++) {
      final px = resized.getPixel(x, y);
      final opacity = px.a / 255.0;
      final r = (px.r * opacity + 255 * (1 - opacity)).round();
      final g = (px.g * opacity + 255 * (1 - opacity)).round();
      final b = (px.b * opacity + 255 * (1 - opacity)).round();
      opaque.setPixelRgba(x, y, r, g, b, 255);
    }
  }
  return PrintExport.setDpi(
      Uint8List.fromList(img.encodePng(opaque)), options.dpi);
}

int _crc32(Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) == 1
          ? ((crc >> 1) ^ 0xEDB88320)
          : crc >> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
