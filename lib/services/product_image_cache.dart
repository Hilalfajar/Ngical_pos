import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Cache foto produk di disk (mirip WA/Telegram):
/// - DB / cloud menyimpan URL publik
/// - UI selalu baca file lokal di folder cache
/// - Kalau belum ada di cache, download sekali lalu simpan
class ProductImageCache {
  ProductImageCache._();
  static final ProductImageCache i = ProductImageCache._();

  Directory? _dir;
  final Map<String, Future<String?>> _inflight = {};

  Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'product_photos_cache'));
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
    return d;
  }

  bool isNetworkUrl(String? s) {
    final t = s?.trim() ?? '';
    return t.startsWith('http://') || t.startsWith('https://');
  }

  bool isLocalPath(String? s) {
    final t = s?.trim() ?? '';
    if (t.isEmpty || isNetworkUrl(t)) return false;
    try {
      return File(t).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Nama file stabil dari URL (atau produkId).
  String _fileNameFor({required String url, int? produkId}) {
    String ext = 'jpg';
    final lower = url.toLowerCase();
    if (lower.contains('.png')) {
      ext = 'png';
    } else if (lower.contains('.webp')) {
      ext = 'webp';
    } else if (lower.contains('.gif')) {
      ext = 'gif';
    }
    if (produkId != null) return 'produk_$produkId.$ext';
    // fallback: potong path URL
    final segs = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    final last = segs.isNotEmpty ? segs.last : 'foto';
    final safe = last.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return safe.isEmpty ? 'foto_${url.hashCode}.$ext' : safe;
  }

  /// Path lokal di cache untuk URL ini (belum tentu file-nya ada).
  Future<String> cachePathFor({required String url, int? produkId}) async {
    final dir = await _cacheDir();
    return p.join(dir.path, _fileNameFor(url: url, produkId: produkId));
  }

  /// Pastikan foto tersedia di lokal.
  /// - path lokal yang valid → return apa adanya
  /// - URL → download ke cache (sekali), return path cache
  /// - gagal → null
  Future<String?> resolveLocalPath(String? foto, {int? produkId}) async {
    if (foto == null || foto.trim().isEmpty) return null;
    final src = foto.trim();

    if (!isNetworkUrl(src)) {
      try {
        if (File(src).existsSync()) return src;
      } catch (_) {}
      return null;
    }

    final dest = await cachePathFor(url: src, produkId: produkId);
    final f = File(dest);
    if (await f.exists() && await f.length() > 50) return dest;

    // Hindari download paralel ganda untuk URL sama
    final existing = _inflight[src];
    if (existing != null) return existing;

    final fut = _download(src, dest);
    _inflight[src] = fut;
    try {
      return await fut;
    } finally {
      _inflight.remove(src);
    }
  }

  Future<String?> _download(String url, String destPath) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200 || res.bodyBytes.length < 50) {
        debugPrint('ProductImageCache download gagal ${res.statusCode}: $url');
        return null;
      }
      final file = File(destPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(res.bodyBytes, flush: true);
      debugPrint('✅ cache foto: $destPath');
      return destPath;
    } catch (e) {
      debugPrint('ProductImageCache error: $e');
      return null;
    }
  }

  /// Setelah sync pull: unduh semua URL yang belum ada di cache (background).
  Future<void> prefetchAll(Iterable<({String? foto, int? id})> items) async {
    for (final it in items) {
      final f = it.foto;
      if (f == null || !isNetworkUrl(f)) continue;
      try {
        await resolveLocalPath(f, produkId: it.id);
      } catch (_) {}
    }
  }

  /// Salin file lokal (hasil kamera/galeri/restore) ke cache dengan nama stabil.
  Future<String?> importLocalFile(String localPath, {int? produkId}) async {
    try {
      final src = File(localPath);
      if (!await src.exists()) return null;
      final dir = await _cacheDir();
      String ext = 'jpg';
      final lower = localPath.toLowerCase();
      if (lower.endsWith('.png')) {
        ext = 'png';
      } else if (lower.endsWith('.webp')) {
        ext = 'webp';
      } else if (lower.endsWith('.gif')) {
        ext = 'gif';
      }
      final name = produkId != null
          ? 'produk_$produkId.$ext'
          : 'produk_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final dest = p.join(dir.path, name);
      await src.copy(dest);
      return dest;
    } catch (e) {
      debugPrint('importLocalFile error: $e');
      return null;
    }
  }
}
