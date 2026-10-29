import 'dart:math' as math;
import 'dart:typed_data';

/// Plan 70: where a JPEG was taken, from its EXIF GPS tags (same rules as web `exif-gps.ts`).
/// Never throws: non-JPEGs, stripped EXIF, broken headers and points outside the Philippines
/// return null.
class PhotoGps {
  const PhotoGps(this.lat, this.lng);
  final double lat;
  final double lng;
}

bool insidePhilippines(double lat, double lng) =>
    lat.isFinite &&
    lng.isFinite &&
    lat >= 4.5 &&
    lat <= 21.5 &&
    lng >= 116 &&
    lng <= 127;

/// How many bytes of a photo to read for EXIF.
const exifHeadBytes = 128 * 1024;

PhotoGps? parseJpegGps(Uint8List bytes) {
  try {
    final view = ByteData.sublistView(bytes);
    if (view.lengthInBytes < 4 || view.getUint16(0) != 0xffd8) return null;
    var offset = 2;
    while (offset + 4 <= view.lengthInBytes) {
      final marker = view.getUint16(offset);
      final size = view.getUint16(offset + 2);
      if ((marker & 0xff00) != 0xff00 || size < 2) return null;
      if (marker == 0xffe1 &&
          offset + 10 <= view.lengthInBytes &&
          view.getUint32(offset + 4) == 0x45786966 &&
          view.getUint16(offset + 8) == 0) {
        return _readTiffGps(view, offset + 10);
      }
      if (marker == 0xffda) return null;
      offset += 2 + size;
    }
    return null;
  } catch (_) {
    return null;
  }
}

PhotoGps? _readTiffGps(ByteData view, int tiff) {
  final order = view.getUint16(tiff);
  if (order != 0x4949 && order != 0x4d4d) return null;
  final endian = order == 0x4949 ? Endian.little : Endian.big;
  int u16(int at) => view.getUint16(at, endian);
  int u32(int at) => view.getUint32(at, endian);
  if (u16(tiff + 2) != 42) return null;
  List<int> entries(int ifd) =>
      List.generate(u16(ifd), (i) => ifd + 2 + i * 12);

  final ifd0 = tiff + u32(tiff + 4);
  final gpsEntry = entries(ifd0).where((e) => u16(e) == 0x8825).firstOrNull;
  if (gpsEntry == null) return null;
  final tags = {for (final e in entries(tiff + u32(gpsEntry + 8))) u16(e): e};

  String? ref(int tag) {
    final e = tags[tag];
    return e == null ? null : String.fromCharCode(view.getUint8(e + 8));
  }

  double? dms(int tag) {
    final e = tags[tag];
    if (e == null || u16(e + 2) != 5 || u32(e + 4) < 3) return null;
    final at = tiff + u32(e + 8);
    double rational(int i) {
      final den = u32(at + i * 8 + 4);
      return den == 0 ? double.nan : u32(at + i * 8) / den;
    }

    return rational(0) + rational(1) / 60 + rational(2) / 3600;
  }

  final latAbs = dms(0x0002), lngAbs = dms(0x0004);
  if (latAbs == null || lngAbs == null) return null;
  final lat = ref(0x0001) == 'S' ? -latAbs : latAbs;
  final lng = ref(0x0003) == 'W' ? -lngAbs : lngAbs;
  if (!insidePhilippines(lat, lng)) return null;
  return PhotoGps((lat * 1e6).round() / 1e6, (lng * 1e6).round() / 1e6);
}

double metersBetween(double lat1, double lng1, double lat2, double lng2) {
  const rad = math.pi / 180;
  final dLat = (lat2 - lat1) * rad, dLng = (lng2 - lng1) * rad;
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1 * rad) *
          math.cos(lat2 * rad) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * 6371000 * math.asin(math.sqrt(h));
}
