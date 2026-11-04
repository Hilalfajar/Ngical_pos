import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sq;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:ngical/data/db.dart';
import 'package:ngical/providers/app.dart';

/// Backup versi online (Ngical_pos): key 'produk'/'transaksi', ID string.
Map<String, dynamic> onlineBackup({
  required String produkId,
  required String trxId,
}) =>
    {
      'version': 2,
      'exportedAt': '2026-11-04T20:41:08.041806',
      'settings': {'storeAddress': 'Karawang', 'ownerName': 'Ghifari'},
      'produk': [
        {
          'id': produkId,
          'nama': 'Good Day Merah',
          'satuan': 'pcs',
          'barcode': '8886010000000',
          'hargaModal': 1400,
          'harga': 2000,
          'stok': 10,
          'foto': 'uploads/produk/3af8833a306e4b0f0a03131c.jpg',
          'kategori': 'Rokok',
        },
      ],
      'transaksi': [
        {
          'id': trxId,
          'tanggal': 1793796781623,
          'totalBelanja': 4000,
          'totalBayar': 5000,
          'kembalian': 1000,
          'noUrut': 81,
          'metode': 'cash',
          'status': 'selesai',
          'namaHutang': '',
        },
      ],
      'transaksiItems': [
        {
          'id': '1',
          'transaksiId': trxId,
          'produkId': produkId,
          'namaProduk': 'Good Day Merah',
          'hargaModal': 1400,
          'hargaSatuan': 2000,
          'jumlah': 2,
          'subtotal': 4000,
        },
      ],
      'staff': [],
    };

/// Backup versi offline: key 'produks'/'transaksis', ID int.
Map<String, dynamic> offlineBackup() => {
      'version': 2,
      'type': 'full',
      'timestamp': 1793796781623,
      'settings': {'storeAddress': 'Karawang'},
      'produks': [
        {
          'id': 5,
          'nama': 'Ciki 2000',
          'satuan': 'pcs',
          'barcode': '8991',
          'hargaModal': 1800,
          'harga': 2000,
          'stok': 4,
          'foto': null,
          'kategori': null,
        },
      ],
      'transaksis': [
        {
          'id': 9,
          'tanggal': 1793796781623,
          'totalBelanja': 2000,
          'totalBayar': 2000,
          'kembalian': 0,
          'noUrut': 1,
          'metode': 'cash',
          'status': 'selesai',
          'namaHutang': '',
        },
      ],
      'transaksiItems': [
        {
          'id': 3,
          'transaksiId': 9,
          'produkId': 5,
          'namaProduk': 'Ciki 2000',
          'hargaModal': 1800,
          'hargaSatuan': 2000,
          'jumlah': 1,
          'subtotal': 2000,
        },
      ],
    };

Future<App> restoreInto(Map<String, dynamic> data) async {
  final app = App();
  await app.init();
  await app.restoreFromJson(data);
  return app;
}

void main() {
  setUpAll(() {
    ffi.sqfliteFfiInit();
    sq.databaseFactory = ffi.databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Database-nya singleton dan file-nya tetap terbuka selama proses test,
    // jadi bersihkan isinya, bukan hapus file.
    await Db.i.clearAll();
  });

  test('restore backup online dengan ID angka string', () async {
    final app = await restoreInto(
        onlineBackup(produkId: '770', trxId: '13979'));

    expect(app.produk.length, 1);
    expect(app.transaksi.length, 1);
    expect(app.allItems.length, 1);
    expect(app.produk.single.nama, 'Good Day Merah');
    expect(app.produk.single.harga, 2000);
    expect(app.produk.single.hargaModal, 1400);
    expect(app.produk.single.stok, 10);
    expect(app.produk.single.kategori, 'Rokok');
    expect(app.transaksi.single.totalBelanja, 4000);
    expect(app.transaksi.single.noUrut, 81);
    // Path foto server tidak ada di mesin ini, jangan ikut tersimpan.
    expect(app.produk.single.foto, isNull);
    // Relasi harus tetap nyambung walau ID lama dipetakan ke ID lokal.
    expect(app.allItems.single.produkId, app.produk.single.id);
    expect(app.allItems.single.transaksiId, app.transaksi.single.id);
    expect(app.allItems.single.jumlah, 2);
    expect(app.allItems.single.subtotal, 4000);
  });

  test('restore backup online dengan ID UUID', () async {
    final app = await restoreInto(onlineBackup(
      produkId: '6f9c1e2a-7b3d-4a55-9c11-2f0a8d7e5b10',
      trxId: 'aa10bb20-cc31-4d42-8e53-ff44ee55dd66',
    ));

    expect(app.produk.length, 1);
    expect(app.allItems.length, 1);
    expect(app.allItems.single.produkId, app.produk.single.id);
    expect(app.allItems.single.transaksiId, app.transaksi.single.id);
  });

  test('restore backup offline tidak berubah perilakunya', () async {
    final app = await restoreInto(offlineBackup());

    expect(app.produk.length, 1);
    expect(app.transaksi.length, 1);
    expect(app.produk.single.nama, 'Ciki 2000');
    expect(app.allItems.single.produkId, app.produk.single.id);
    expect(app.allItems.single.transaksiId, app.transaksi.single.id);
  });

  test('restore file yang sama dua kali tidak menghasilkan data dobel',
      () async {
    final app = App();
    await app.init();
    final data = onlineBackup(produkId: '770', trxId: '13979');
    await app.restoreFromJson(data);
    await app.restoreFromJson(data);

    expect(app.produk.length, 1);
    expect(app.transaksi.length, 1);
    expect(app.allItems.length, 1);
  });

  test('backup online tanpa storeName tidak menghapus nama toko lokal',
      () async {
    final app = App();
    await app.init();
    app.storeName = 'Toko Ghifari';
    await app.restoreFromJson(onlineBackup(produkId: '1', trxId: '1'));

    expect(app.storeName, 'Toko Ghifari');
    expect(app.storeAddress, 'Karawang');
  });

  test('foto yang benar-benar ada di mesin ini tidak dibuang', () async {
    final file =
        File(join(Directory.systemTemp.path, 'ngical_restore_foto.jpg'));
    await file.writeAsBytes([1, 2, 3]);
    addTearDown(() => file.deleteSync());

    final data = onlineBackup(produkId: '1', trxId: '1');
    // Persis hasil _restoreZip: entri foto/... dari ZIP dipetakan ke
    // path lokal sebelum restoreFromJson jalan.
    (data['produk'] as List).first['foto'] = file.path;

    final app = App();
    await app.init();
    await app.restoreFromJson(data);

    expect(app.produk.single.foto, file.path);
  });
}
