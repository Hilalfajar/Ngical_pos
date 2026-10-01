import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/app.dart';

/// Folder khusus buat hasil backup otomatis, terpisah dari backup manual
/// (yang disimpan user lewat halaman Backup & Restore) supaya tidak
/// bercampur dan gampang dibersihkan.
Future<String> autoBackupDir() async {
  if (Platform.isAndroid) {
    return '/storage/emulated/0/Download/NgicalAutoBackup';
  }
  final d = await getApplicationDocumentsDirectory();
  return '${d.path}/NgicalAutoBackup';
}

/// Jalankan satu kali backup otomatis (dipanggil dari
/// App.checkAndRunScheduledBackupIfDue). [scope] adalah 'all' atau 'produk'.
/// [app] harus sudah di-refresh (refreshProduk/refreshTrx) sebelum dipanggil
/// supaya datanya terbaru.
Future<String> runAutoBackup(App app, {required String scope}) async {
  final dir = await autoBackupDir();
  await Directory(dir).create(recursive: true);
  final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

  String savedPath;
  if (scope == 'produk') {
    // ZIP + foto, sama seperti backup manual produk
    final archive = Archive();
    final jsonStr =
        const JsonEncoder.withIndent('  ').convert(app.exportProdukMap());
    final jsonBytes = utf8.encode(jsonStr);
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    for (final p in app.produk) {
      if (p.foto != null && File(p.foto!).existsSync()) {
        final fotoBytes = await File(p.foto!).readAsBytes();
            final base = p.foto!.split('/').last.split('\\').last;
        final fotoName = 'foto/${p.id}_$base';
        archive.addFile(ArchiveFile(fotoName, fotoBytes.length, fotoBytes));
      }
    }

    final zipBytes = ZipEncoder().encode(archive)!;
    final f = File('$dir/AutoBackup_Produk_$ts.zip');
    await f.writeAsBytes(zipBytes, flush: true);
    savedPath = f.path;
  } else {
    final archive = Archive();
    final jsonStr =
        const JsonEncoder.withIndent('  ').convert(app.exportBackupMap());
    final jsonBytes = utf8.encode(jsonStr);
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    for (final p in app.produk) {
      if (p.foto != null && File(p.foto!).existsSync()) {
        final fotoBytes = await File(p.foto!).readAsBytes();
        final fotoName =
            'foto/${p.id}_${p.foto!.split('/').last.split('\\').last}';
        archive.addFile(ArchiveFile(fotoName, fotoBytes.length, fotoBytes));
      }
    }

    final zipBytes = ZipEncoder().encode(archive)!;
    final f = File('$dir/AutoBackup_Semua_$ts.zip');
    await f.writeAsBytes(zipBytes, flush: true);
    savedPath = f.path;
  }

  await _cleanupOldBackups(dir, keep: 5);
  return savedPath;
}

/// Simpan storage HP: cuma simpan 5 backup otomatis terbaru, sisanya dihapus.
Future<void> _cleanupOldBackups(String dirPath, {required int keep}) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return;
  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));
  if (files.length > keep) {
    for (final f in files.skip(keep)) {
      try {
        await f.delete();
      } catch (_) {
        // abaikan, bukan hal fatal
      }
    }
  }
}
