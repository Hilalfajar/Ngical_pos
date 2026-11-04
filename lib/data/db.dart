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
      version: 12,
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
        if (oldV < 11) {
          await d.execute('DROP TABLE IF EXISTS resep_item');
          await d.execute('DROP TABLE IF EXISTS bahan');
          try {
            await d.execute('ALTER TABLE produk DROP COLUMN gunakanHpp');
          } catch (_) {}
        }
        if (oldV < 12) {
          await d.execute('DROP TABLE IF EXISTS staff');
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
      // Restore stok produk
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

  Future<void> clearAll() async {
    final d = await db;
    await d.delete('transaksi_item');
    await d.delete('transaksi');
    await d.delete('produk');
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

  /// Restore backup besar dalam satu transaksi database.
  /// ID lama dipetakan ke ID baru supaya relasi item tetap benar walaupun
  /// ID dari file berbeda dengan ID yang diberikan SQLite.
  Future<Map<String, int>> restoreFromBackup({
    required List<Produk> produks,
    required List<Transaksi> transaksis,
    required Map<int, List<TransaksiItem>> itemsByTrx,
    Map<int, int> existingProdukIds = const {},
  }) async {
    final d = await db;
    // existingProdukIds: ID produk di file -> ID produk yang sudah ada di DB.
    final produkMap = <int, int>{...existingProdukIds};
    final trxMap = <int, int>{};
    var addedItems = 0;

    await d.transaction((txn) async {
      for (final p in produks) {
        final oldId = p.id;
        final row = Map<String, dynamic>.from(p.toMap())..remove('id');
        final newId = await txn.insert('produk', row);
        if (oldId != null) produkMap[oldId] = newId;
      }

      for (final t in transaksis) {
        final oldId = t.id;
        final newId = await txn.insert(
          'transaksi',
          Transaksi(
            tanggal: t.tanggal,
            totalBelanja: t.totalBelanja,
            totalBayar: t.totalBayar,
            kembalian: t.kembalian,
            noUrut: t.noUrut,
            metode: t.metode,
            status: t.status,
            namaHutang: t.namaHutang,
          ).toMap(),
        );
        if (oldId != null) trxMap[oldId] = newId;

        final items = oldId == null
            ? const <TransaksiItem>[]
            : (itemsByTrx[oldId] ?? const <TransaksiItem>[]);
        for (final it in items) {
          await txn.insert(
            'transaksi_item',
            TransaksiItem(
              transaksiId: newId,
              produkId: produkMap[it.produkId] ?? 0,
              namaProduk: it.namaProduk,
              hargaModal: it.hargaModal,
              hargaSatuan: it.hargaSatuan,
              jumlah: it.jumlah,
              subtotal: it.subtotal,
            ).toMap(),
          );
          addedItems++;
        }
      }
    });

    return {
      'produk': produks.length,
      'transaksi': transaksis.length,
      'items': addedItems,
    };
  }
}
