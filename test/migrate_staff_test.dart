import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sq;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:ngical/data/db.dart';

/// Latih migrasi v11 -> v12 (DROP TABLE staff) di database sungguhan sebelum
/// dipakai di mesin toko.
///
/// Database dibuat di folder sementara, jadi test ini tidak pernah menyentuh
/// warung_db.db milik toko.
void main() {
  late String dbPath;
  late Directory scratch;
  late Directory asal;

  setUpAll(() {
    ffi.sqfliteFfiInit();
    ffi.databaseFactory = ffi.databaseFactoryFfi;
    asal = Directory.current;
    scratch = Directory.systemTemp.createTempSync('ngical_migrate_staff');
    Directory.current = scratch.path;
  });

  tearDownAll(() {
    Directory.current = asal;
    // Db.i menyimpan handle database sampai proses mati, jadi Windows menolak
    // menghapusnya. Bersihkan kalau bisa, biarkan kalau tidak.
    try {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    } on FileSystemException {
      // sengaja diabaikan
    }
  });

  test('database v11 dinaikkan ke v12: tabel staff hilang, produk aman',
      () async {
    dbPath = p.join(await sq.getDatabasesPath(), 'warung_db.db');

    final old = await ffi.openDatabase(
      dbPath,
      version: 11,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE produk(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nama TEXT NOT NULL,
            satuan TEXT NOT NULL DEFAULT 'pcs',
            barcode TEXT,
            hargaModal INTEGER NOT NULL DEFAULT 0,
            harga INTEGER NOT NULL,
            stok REAL NOT NULL,
            foto TEXT,
            kategori TEXT
          )''');
        await d.execute('''
          CREATE TABLE staff(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nama TEXT NOT NULL,
            pin TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'Kasir',
            aktif INTEGER NOT NULL DEFAULT 1,
            permissions TEXT NOT NULL DEFAULT ''
          )''');
      },
    );
    await old.insert('produk', {'nama': 'Indomie', 'harga': 3500, 'stok': 10});
    await old.insert('staff', {'nama': 'Budi', 'pin': '1234'});
    expect(await old.rawQuery('SELECT * FROM staff'), hasLength(1));
    await old.close();

    final db = await Db.i.db;
    // Pastikan yang terbuka benar-benar database sementara ini, bukan warung_db.db
    // toko yang mungkin sudah di-cache oleh suite lain.
    expect(db.path, dbPath);

    final staffTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='staff'");
    expect(staffTable, isEmpty, reason: 'tabel staff harus hilang');

    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.first.values.first, 12);

    final produk = await Db.i.allProduk();
    expect(produk, hasLength(1));
    expect(produk.first.nama, 'Indomie');
  });
}
