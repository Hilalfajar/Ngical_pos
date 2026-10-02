import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class Db {
  Db._();
  static final Db i = Db._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'warung_db.db');
    _db = await openDatabase(
      path,
      version: 10,
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
            kategori TEXT,
            gunakanHpp INTEGER NOT NULL DEFAULT 0
          )''');
        await d.execute('''
          CREATE TABLE transaksi(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tanggal INTEGER NOT NULL,
            totalBelanja INTEGER NOT NULL,
            totalBayar INTEGER NOT NULL,
            kembalian INTEGER NOT NULL,
            noUrut INTEGER NOT NULL DEFAULT 0,
            metode TEXT NOT NULL DEFAULT 'cash',
            status TEXT NOT NULL DEFAULT 'selesai',
            namaHutang TEXT NOT NULL DEFAULT ''
          )''');
        await d.execute('''
          CREATE TABLE transaksi_item(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaksiId INTEGER NOT NULL,
            produkId INTEGER NOT NULL,
            namaProduk TEXT NOT NULL,
            hargaModal INTEGER NOT NULL DEFAULT 0,
            hargaSatuan INTEGER NOT NULL,
            jumlah REAL NOT NULL,
            subtotal INTEGER NOT NULL
          )''');
        await d.execute('''
          CREATE TABLE bahan(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nama TEXT NOT NULL,
            satuan TEXT NOT NULL DEFAULT 'g',
            hargaBeli INTEGER NOT NULL DEFAULT 0,
            jumlahBeli REAL NOT NULL DEFAULT 1,
            stok REAL NOT NULL DEFAULT 0
          )''');
        await d.execute('''
          CREATE TABLE resep_item(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            produkId INTEGER NOT NULL,
            bahanId INTEGER NOT NULL,
            qty REAL NOT NULL
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
        await d.execute('''
          CREATE TABLE produk_tier(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            produkId INTEGER NOT NULL,
            minQty REAL NOT NULL,
            harga INTEGER NOT NULL,
            label TEXT NOT NULL DEFAULT ''
          )''');
        await d.execute('''
          CREATE TABLE stok_update(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tanggal INTEGER NOT NULL,
            noUrut INTEGER NOT NULL,
            totalItem INTEGER NOT NULL,
            totalQty REAL NOT NULL
          )''');
        await d.execute('''
          CREATE TABLE stok_update_item(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            updateId INTEGER NOT NULL,
            produkId INTEGER NOT NULL,
            namaProduk TEXT NOT NULL,
            qty REAL NOT NULL,
            stokSebelum REAL NOT NULL,
            stokSesudah REAL NOT NULL
          )''');
      },
      onUpgrade: (d, oldV, newV) async {
        if (oldV < 2) {
          try {
            await d.execute(
                "ALTER TABLE transaksi ADD COLUMN metode TEXT NOT NULL DEFAULT 'cash'");
          } catch (_) {}
          try {
            await d.execute(
                "ALTER TABLE transaksi ADD COLUMN status TEXT NOT NULL DEFAULT 'selesai'");
          } catch (_) {}
        }
        if (oldV < 3) {
          try {
            await d.execute(
                "ALTER TABLE produk ADD COLUMN satuan TEXT NOT NULL DEFAULT 'pcs'");
          } catch (_) {}
        }
        if (oldV < 4) {
          try {
            await d.execute(
                "ALTER TABLE transaksi ADD COLUMN noUrut INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}
        }
        if (oldV < 5) {
          try {
            await d.execute(
                "ALTER TABLE transaksi ADD COLUMN namaHutang TEXT NOT NULL DEFAULT ''");
          } catch (_) {}
        }
        if (oldV < 6) {
          try {
            await d.execute(
                "ALTER TABLE produk ADD COLUMN gunakanHpp INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}
          await d.execute('''
            CREATE TABLE IF NOT EXISTS bahan(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nama TEXT NOT NULL,
              satuan TEXT NOT NULL DEFAULT 'g',
              hargaBeli INTEGER NOT NULL DEFAULT 0,
              jumlahBeli REAL NOT NULL DEFAULT 1,
              stok REAL NOT NULL DEFAULT 0
            )''');
          await d.execute('''
            CREATE TABLE IF NOT EXISTS resep_item(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              produkId INTEGER NOT NULL,
              bahanId INTEGER NOT NULL,
              qty REAL NOT NULL
            )''');
        }
        if (oldV < 7) {
          await d.execute('''
            CREATE TABLE IF NOT EXISTS staff(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nama TEXT NOT NULL,
              pin TEXT NOT NULL,
              role TEXT NOT NULL DEFAULT 'Kasir',
              aktif INTEGER NOT NULL DEFAULT 1,
              permissions TEXT NOT NULL DEFAULT ''
            )''');
        }
        if (oldV < 8) {
          await d.execute('''
            CREATE TABLE IF NOT EXISTS produk_tier(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              produkId INTEGER NOT NULL,
              minQty REAL NOT NULL,
              harga INTEGER NOT NULL,
              label TEXT NOT NULL DEFAULT ''
            )''');
        }
        if (oldV < 9) {
          await d.execute('''
            CREATE TABLE IF NOT EXISTS stok_update(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              tanggal INTEGER NOT NULL,
              noUrut INTEGER NOT NULL,
              totalItem INTEGER NOT NULL,
              totalQty REAL NOT NULL
            )''');
          await d.execute('''
            CREATE TABLE IF NOT EXISTS stok_update_item(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              updateId INTEGER NOT NULL,
              produkId INTEGER NOT NULL,
              namaProduk TEXT NOT NULL,
              qty REAL NOT NULL,
              stokSebelum REAL NOT NULL,
              stokSesudah REAL NOT NULL
            )''');
        }
        if (oldV < 10) {
          try {
            await d.execute("ALTER TABLE produk ADD COLUMN kategori TEXT");
          } catch (_) {}
        }
      },
    );
    return _db!;
  }

  Future<List<Produk>> allProduk() async {
    final rows = await (await db).query('produk', orderBy: 'nama ASC');
    return rows.map(Produk.fromMap).toList();
  }

  Future<int> insertProduk(Produk p) async =>
      (await db).insert('produk', p.toMap());

  Future<int> updateProduk(Produk p) async =>
      (await db).update('produk', p.toMap(), where: 'id=?', whereArgs: [p.id]);

  Future<int> deleteProduk(int id) async =>
      (await db).delete('produk', where: 'id=?', whereArgs: [id]);

  Future<void> kurangiStok(int id, double n) async =>
      (await db).rawUpdate('UPDATE produk SET stok=stok-? WHERE id=?', [n, id]);

  Future<void> tambahStok(int id, double n) async =>
      (await db).rawUpdate('UPDATE produk SET stok=stok+? WHERE id=?', [n, id]);

  // ── Harga paket / grosir ──────────────────────────────────
  Future<List<HargaTier>> allTiers() async {
    final rows = await (await db).query('produk_tier', orderBy: 'minQty ASC');
    return rows.map(HargaTier.fromMap).toList();
  }

  Future<List<HargaTier>> tiersOf(int produkId) async {
    final rows = await (await db).query(
      'produk_tier',
      where: 'produkId=?',
      whereArgs: [produkId],
      orderBy: 'minQty ASC',
    );
    return rows.map(HargaTier.fromMap).toList();
  }

  Future<void> setTiers(int produkId, List<HargaTier> tiers) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn
          .delete('produk_tier', where: 'produkId=?', whereArgs: [produkId]);
      for (final t in tiers) {
        if (t.minQty <= 0 || t.harga <= 0) continue;
        await txn.insert(
          'produk_tier',
          {
            'produkId': produkId,
            'minQty': t.minQty,
            'harga': t.harga,
            'label': t.label,
          },
        );
      }
    });
  }

  Future<void> deleteTiersOf(int produkId) async => (await db)
      .delete('produk_tier', where: 'produkId=?', whereArgs: [produkId]);

  Future<List<StokUpdate>> allStokUpdate() async {
    final rows = await (await db).query('stok_update', orderBy: 'tanggal DESC');
    return rows.map(StokUpdate.fromMap).toList();
  }

  Future<List<StokUpdateItem>> stokUpdateItemsOf(int updateId) async {
    final rows = await (await db).query(
      'stok_update_item',
      where: 'updateId=?',
      whereArgs: [updateId],
      orderBy: 'id ASC',
    );
    return rows.map(StokUpdateItem.fromMap).toList();
  }

  Future<int> catatStokUpdate({
    required List<StokUpdateItem> items,
  }) async {
    final d = await db;
    late int id;
    await d.transaction((txn) async {
      final now = DateTime.now();
      final start =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59)
          .millisecondsSinceEpoch;
      final count = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM stok_update WHERE tanggal BETWEEN ? AND ?',
            [start, end],
          )) ??
          0;
      final noUrut = count + 1;
      final totalQty = items.fold<double>(0, (s, e) => s + e.qty);
      id = await txn.insert(
        'stok_update',
        {
          'tanggal': now.millisecondsSinceEpoch,
          'noUrut': noUrut,
          'totalItem': items.length,
          'totalQty': totalQty,
        },
      );
      for (final it in items) {
        await txn.insert(
          'stok_update_item',
          it.toMap()..['updateId'] = id,
        );
        await txn.rawUpdate(
          'UPDATE produk SET stok = stok + ? WHERE id = ?',
          [it.qty, it.produkId],
        );
      }
    });
    return id;
  }

  // ── Bahan baku ──────────────────────────────────────────────
  Future<List<Bahan>> allBahan() async {
    final rows = await (await db).query('bahan', orderBy: 'nama ASC');
    return rows.map(Bahan.fromMap).toList();
  }

  Future<int> insertBahan(Bahan b) async =>
      (await db).insert('bahan', b.toMap());

  Future<int> updateBahan(Bahan b) async =>
      (await db).update('bahan', b.toMap(), where: 'id=?', whereArgs: [b.id]);

  Future<int> deleteBahan(int id) async {
    final d = await db;
    await d.delete('resep_item', where: 'bahanId=?', whereArgs: [id]);
    return d.delete('bahan', where: 'id=?', whereArgs: [id]);
  }

  // ── Resep ───────────────────────────────────────────────────
  Future<List<ResepItem>> resepOf(int produkId) async {
    final rows = await (await db)
        .query('resep_item', where: 'produkId=?', whereArgs: [produkId]);
    return rows.map(ResepItem.fromMap).toList();
  }

  Future<List<ResepItem>> allResep() async {
    final rows = await (await db).query('resep_item');
    return rows.map(ResepItem.fromMap).toList();
  }

  /// Ganti seluruh resep produk (hapus lama + insert baru)
  Future<void> setResep(int produkId, List<ResepItem> items) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn
          .delete('resep_item', where: 'produkId=?', whereArgs: [produkId]);
      for (final it in items) {
        await txn.insert('resep_item', it.toMap()..['produkId'] = produkId);
      }
    });
  }

  Future<void> deleteResepOf(int produkId) async => (await db)
      .delete('resep_item', where: 'produkId=?', whereArgs: [produkId]);

  Future<List<Transaksi>> allTransaksi() async {
    final rows = await (await db).query('transaksi', orderBy: 'tanggal DESC');
    return rows.map(Transaksi.fromMap).toList();
  }

  Future<List<TransaksiItem>> itemsOf(int trxId) async {
    final rows = await (await db)
        .query('transaksi_item', where: 'transaksiId=?', whereArgs: [trxId]);
    return rows.map(TransaksiItem.fromMap).toList();
  }

  Future<List<TransaksiItem>> allItems() async {
    final rows = await (await db).query('transaksi_item');
    return rows.map(TransaksiItem.fromMap).toList();
  }

  Future<int> insertTransaksi(Transaksi t) async =>
      (await db).insert('transaksi', t.toMap());

  Future<void> insertItems(List<TransaksiItem> items) async {
    final d = await db;
    final b = d.batch();
    for (final it in items) {
      b.insert('transaksi_item', it.toMap());
    }
    await b.commit(noResult: true);
  }

  /// Mencatat satu transaksi penjualan secara ATOMIC:
  /// insert transaksi + insert semua item + potong stok tiap produk,
  /// semuanya dalam satu db.transaction(). Kalau salah satu langkah
  /// gagal (mis. app crash di tengah jalan), SEMUA di-rollback
  /// sehingga data tidak pernah "nyangkut" separuh jalan.
  ///
  /// [items] adalah list pasangan (TransaksiItem tanpa transaksiId, qty
  /// untuk potong stok). transaksiId akan diisi otomatis setelah insert.
  Future<int> catatTransaksi({
    required Transaksi transaksi,
    required List<TransaksiItem> items,
  }) async {
    final d = await db;
    late final int trxId;
    await d.transaction((txn) async {
      // Hitung noUrut hari ini
      final now = DateTime.now();
      final start =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59)
          .millisecondsSinceEpoch;

      final count = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COUNT(*) FROM transaksi WHERE tanggal BETWEEN ? AND ?',
              [start, end])) ??
          0;

      final nextNoUrut = count + 1;

      trxId = await txn.insert(
          'transaksi', transaksi.toMap()..['noUrut'] = nextNoUrut);

      final batch = txn.batch();
      for (final it in items) {
        batch.insert(
          'transaksi_item',
          it.toMap()..['transaksiId'] = trxId,
        );
        // Potong stok produk jadi
        batch.rawUpdate(
          'UPDATE produk SET stok = stok - ? WHERE id = ?',
          [it.jumlah, it.produkId],
        );
      }
      await batch.commit(noResult: true);

      // Potong stok bahan baku sesuai resep HPP
      for (final it in items) {
        final resep = await txn.query(
          'resep_item',
          where: 'produkId=?',
          whereArgs: [it.produkId],
        );
        for (final r in resep) {
          final bahanId = r['bahanId'] as int;
          final qtyResep = (r['qty'] as num).toDouble();
          final potong = qtyResep * it.jumlah;
          await txn.rawUpdate(
            'UPDATE bahan SET stok = stok - ? WHERE id = ?',
            [potong, bahanId],
          );
        }
      }
    });
    return trxId;
  }

  Future<void> cancelTransaksi(int trxId) async {
    final d = await db;
    await d.transaction((txn) async {
      // Mark as batal
      await txn.update(
        'transaksi',
        {'status': 'batal'},
        where: 'id=?',
        whereArgs: [trxId],
      );
      // Restore stok produk + bahan
      final items = await txn.query(
        'transaksi_item',
        where: 'transaksiId=?',
        whereArgs: [trxId],
      );
      for (final item in items) {
        final produkId = item['produkId'] as int;
        final jumlah = (item['jumlah'] as num).toDouble();
        await txn.rawUpdate(
          'UPDATE produk SET stok=stok+? WHERE id=?',
          [jumlah, produkId],
        );
        // Kembalikan stok bahan dari resep
        final resep = await txn.query(
          'resep_item',
          where: 'produkId=?',
          whereArgs: [produkId],
        );
        for (final r in resep) {
          final bahanId = r['bahanId'] as int;
          final qtyResep = (r['qty'] as num).toDouble();
          await txn.rawUpdate(
            'UPDATE bahan SET stok=stok+? WHERE id=?',
            [qtyResep * jumlah, bahanId],
          );
        }
      }
    });
  }

  Future<void> updateTransaksiStatus(int trxId, String status,
      {int? totalBayar, int? kembalian}) async {
    final d = await db;
    final data = <String, dynamic>{'status': status};
    if (totalBayar != null) data['totalBayar'] = totalBayar;
    if (kembalian != null) data['kembalian'] = kembalian;
    await d.update('transaksi', data, where: 'id=?', whereArgs: [trxId]);
  }

  // ── Staff ──────────────────────────────────────────────────
  Future<List<Staff>> allStaff() async {
    final rows = await (await db).query('staff', orderBy: 'role ASC, nama ASC');
    return rows.map(Staff.fromMap).toList();
  }

  Future<int> insertStaff(Staff s) async =>
      (await db).insert('staff', s.toMap());

  Future<int> updateStaff(Staff s) async =>
      (await db).update('staff', s.toMap(), where: 'id=?', whereArgs: [s.id]);

  Future<int> deleteStaff(int id) async =>
      (await db).delete('staff', where: 'id=?', whereArgs: [id]);

  Future<Staff?> staffById(int id) async {
    final rows = await (await db)
        .query('staff', where: 'id=?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Staff.fromMap(rows.first);
  }

  Future<void> clearAll() async {
    final d = await db;
    await d.delete('transaksi_item');
    await d.delete('transaksi');
    await d.delete('resep_item');
    await d.delete('bahan');
    await d.delete('produk');
    // staff tidak dihapus saat clear data toko
  }

  Future<void> restoreBackup({
    required List<Produk> produks,
    required List<Transaksi> transaksis,
    required List<TransaksiItem> items,
  }) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('transaksi_item');
      await txn.delete('transaksi');
      await txn.delete('produk');
      for (final p in produks) {
        await txn.insert('produk', p.toMap());
      }
      for (final t in transaksis) {
        await txn.insert('transaksi', t.toMap());
      }
      for (final it in items) {
        await txn.insert('transaksi_item', it.toMap());
      }
    });
  }

  Future<void> replaceAllProduk(List<Produk> produks) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('produk');
      for (final p in produks) {
        await txn.insert('produk', p.toMap());
      }
    });
  }
}
