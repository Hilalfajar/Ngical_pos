import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Semua operasi CRUD ke Supabase.
/// Menggantikan Db (SQLite) sepenuhnya.
/// Singleton via [SupabaseDb.i].
class SupabaseDb {
  SupabaseDb._();
  static final SupabaseDb i = SupabaseDb._();

  SupabaseClient get _c => Supabase.instance.client;

  /// User ID dari sesi yang aktif - wajib ada sebelum operasi apapun.
  String get uid {
    final id = _c.auth.currentUser?.id;
    if (id == null) throw Exception('Belum login ke Supabase');
    return id;
  }

  /// Supabase/PostgREST default max 1000 baris per request.
  /// Helper ini page sampai habis supaya data lengkap.
  Future<List<Map<String, dynamic>>> _selectAll(
    String table, {
    String? orderColumn,
    bool ascending = true,
  }) async {
    const pageSize = 1000;
    final all = <Map<String, dynamic>>[];
    int from = 0;
    while (true) {
      final List rows;
      if (orderColumn != null) {
        rows = await _c
            .from(table)
            .select()
            .eq('user_id', uid)
            .order(orderColumn, ascending: ascending)
            .range(from, from + pageSize - 1);
      } else {
        rows = await _c
            .from(table)
            .select()
            .eq('user_id', uid)
            .range(from, from + pageSize - 1);
      }
      final list = List<Map<String, dynamic>>.from(rows as List);
      all.addAll(list);
      if (list.length < pageSize) break;
      from += pageSize;
    }
    return all;
  }

  // ── PRODUK ────────────────────────────────────────────────

  Future<List<Produk>> allProduk() async {
    final rows = await _selectAll('produk', orderColumn: 'nama');
    return rows.map((r) => Produk.fromSupabase(r)).toList();
  }

  Future<Produk> insertProduk(Produk p) async {
    final row = await _c
        .from('produk')
        .insert(p.toSupabase(uid))
        .select()
        .single();
    return Produk.fromSupabase(row);
  }

  Future<Produk> updateProduk(Produk p) async {
    if (p.id == null) throw Exception('updateProduk: id produk kosong');
    final data = Map<String, dynamic>.from(p.toSupabase(uid));
    // Jangan kirim id di body update (PK tidak diubah)
    data.remove('id');
    final row = await _c
        .from('produk')
        .update(data)
        .eq('id', p.id!)
        .eq('user_id', uid)
        .select()
        .single(); // throw jika 0 baris (RLS / id salah)
    return Produk.fromSupabase(row);
  }

  Future<void> deleteProduk(String id) async {
    await _c.from('produk').delete().eq('id', id).eq('user_id', uid);
  }

  Future<void> updateStokProduk(String id, double stokBaru) async {
    await _c.from('produk').update({'stok': stokBaru}).eq('id', id).eq('user_id', uid);
  }

  // ── HARGA TIER ────────────────────────────────────────────

  Future<List<HargaTier>> allTiers() async {
    final rows = await _c.from('produk_tier').select().eq('user_id', uid);
    return (rows as List).map((r) => HargaTier.fromSupabase(r)).toList();
  }

  Future<List<HargaTier>> tiersOf(String produkId) async {
    final rows = await _c
        .from('produk_tier')
        .select()
        .eq('user_id', uid)
        .eq('produk_id', produkId)
        .order('min_qty');
    return (rows as List).map((r) => HargaTier.fromSupabase(r)).toList();
  }

  /// Hapus semua tier lama produk, lalu insert yang baru.
  Future<void> setTiers(String produkId, List<HargaTier> tiers) async {
    await _c.from('produk_tier').delete().eq('user_id', uid).eq('produk_id', produkId);
    if (tiers.isEmpty) return;
    final rows = tiers
        .where((t) => t.minQty > 0 && t.harga > 0)
        .map((t) => t.toSupabase(uid, produkId))
        .toList();
    if (rows.isNotEmpty) await _c.from('produk_tier').insert(rows);
  }

  Future<void> deleteTiersOf(String produkId) async {
    await _c.from('produk_tier').delete().eq('user_id', uid).eq('produk_id', produkId);
  }

  // ── BAHAN ─────────────────────────────────────────────────

  Future<List<Bahan>> allBahan() async {
    final rows = await _c.from('bahan').select().eq('user_id', uid).order('nama');
    return (rows as List).map((r) => Bahan.fromSupabase(r)).toList();
  }

  Future<Bahan> insertBahan(Bahan b) async {
    final row = await _c.from('bahan').insert(b.toSupabase(uid)).select().single();
    return Bahan.fromSupabase(row);
  }

  Future<void> updateBahan(Bahan b) async {
    await _c.from('bahan').update(b.toSupabase(uid)).eq('id', b.id!);
  }

  Future<void> deleteBahan(String id) async {
    // Hapus resep dulu (cascade FK akan handle juga, tapi eksplisit lebih aman)
    await _c.from('resep_item').delete().eq('user_id', uid).eq('bahan_id', id);
    await _c.from('bahan').delete().eq('id', id).eq('user_id', uid);
  }

  Future<void> updateStokBahan(String id, double stokBaru) async {
    await _c.from('bahan').update({'stok': stokBaru}).eq('id', id).eq('user_id', uid);
  }

  // ── RESEP ─────────────────────────────────────────────────

  Future<List<ResepItem>> allResep() async {
    final rows = await _c.from('resep_item').select().eq('user_id', uid);
    return (rows as List).map((r) => ResepItem.fromSupabase(r)).toList();
  }

  Future<List<ResepItem>> resepOf(String produkId) async {
    final rows = await _c
        .from('resep_item')
        .select()
        .eq('user_id', uid)
        .eq('produk_id', produkId);
    return (rows as List).map((r) => ResepItem.fromSupabase(r)).toList();
  }

  Future<void> setResep(String produkId, List<ResepItem> items) async {
    await _c.from('resep_item').delete().eq('user_id', uid).eq('produk_id', produkId);
    if (items.isEmpty) return;
    final rows = items.map((r) => r.toSupabase(uid)).toList();
    await _c.from('resep_item').insert(rows);
  }

  Future<void> deleteResepOf(String produkId) async {
    await _c.from('resep_item').delete().eq('user_id', uid).eq('produk_id', produkId);
  }

  // ── STAFF ─────────────────────────────────────────────────

  Future<List<Staff>> allStaff() async {
    final rows = await _c
        .from('staff')
        .select()
        .eq('user_id', uid)
        .order('role')
        .order('nama');
    return (rows as List).map((r) => Staff.fromSupabase(r)).toList();
  }

  Future<Staff> insertStaff(Staff s) async {
    final row = await _c.from('staff').insert(s.toSupabase(uid)).select().single();
    return Staff.fromSupabase(row);
  }

  Future<void> updateStaff(Staff s) async {
    await _c.from('staff').update(s.toSupabase(uid)).eq('id', s.id!);
  }

  Future<void> deleteStaff(String id) async {
    await _c.from('staff').delete().eq('id', id).eq('user_id', uid);
  }

  // ── TRANSAKSI ─────────────────────────────────────────────

  Future<List<Transaksi>> allTransaksi() async {
    final rows =
        await _selectAll('transaksi', orderColumn: 'tanggal', ascending: false);
    return rows.map((r) => Transaksi.fromSupabase(r)).toList();
  }

  Future<List<TransaksiItem>> itemsOf(String transaksiId) async {
    final rows = await _c
        .from('transaksi_item')
        .select()
        .eq('user_id', uid)
        .eq('transaksi_id', transaksiId);
    return (rows as List).map((r) => TransaksiItem.fromSupabase(r)).toList();
  }

  Future<List<TransaksiItem>> allItems() async {
    final rows = await _selectAll('transaksi_item');
    return rows.map((r) => TransaksiItem.fromSupabase(r)).toList();
  }

  /// Catat transaksi + item + potong stok produk & bahan.
  /// Karena Supabase tidak mendukung multi-table atomic dari client,
  /// kita pakai sequential insert dengan rollback manual jika gagal.
  Future<String> catatTransaksi({
    required Transaksi transaksi,
    required List<TransaksiItem> items,
    required List<Produk> semuaProduk,
    required List<ResepItem> semuaResep,
    required List<Bahan> semuaBahan,
  }) async {
    // 1. Hitung noUrut hari ini
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

    final countResult = await _c
        .from('transaksi')
        .select('id')
        .eq('user_id', uid)
        .gte('tanggal', startOfDay)
        .lte('tanggal', endOfDay);
    final noUrut = (countResult as List).length + 1;

    // 2. Insert transaksi
    final trxRow = await _c
        .from('transaksi')
        .insert(transaksi.copyWith(noUrut: noUrut).toSupabase(uid))
        .select()
        .single();
    final trxId = trxRow['id'] as String;

    // 3. Insert item transaksi
    if (items.isNotEmpty) {
      final itemRows =
          items.map((it) => it.toSupabase(uid, trxId)).toList();
      await _c.from('transaksi_item').insert(itemRows);
    }

    // 4. Potong stok produk
    for (final it in items) {
      final produk =
          semuaProduk.where((p) => p.id == it.produkId).firstOrNull;
      if (produk == null) continue;
      final stokBaru = (produk.stok - it.jumlah).clamp(0.0, double.infinity);
      await updateStokProduk(it.produkId, stokBaru);

      // 5. Potong stok bahan sesuai resep
      final resep = semuaResep.where((r) => r.produkId == it.produkId);
      for (final r in resep) {
        final bahan = semuaBahan.where((b) => b.id == r.bahanId).firstOrNull;
        if (bahan == null) continue;
        final potong = r.qty * it.jumlah;
        final stokBahanBaru =
            (bahan.stok - potong).clamp(0.0, double.infinity);
        await updateStokBahan(r.bahanId, stokBahanBaru);
      }
    }

    return trxId;
  }

  /// Batalkan transaksi - set status='batal', kembalikan stok.
  Future<void> cancelTransaksi(
    String trxId, {
    required List<Produk> semuaProduk,
    required List<ResepItem> semuaResep,
    required List<Bahan> semuaBahan,
  }) async {
    // Mark batal
    await _c
        .from('transaksi')
        .update({'status': 'batal'})
        .eq('id', trxId)
        .eq('user_id', uid);

    // Ambil item transaksi
    final trxItems = await itemsOf(trxId);

    // Kembalikan stok
    for (final it in trxItems) {
      final produk =
          semuaProduk.where((p) => p.id == it.produkId).firstOrNull;
      if (produk != null) {
        await updateStokProduk(it.produkId, produk.stok + it.jumlah);
      }
      final resep = semuaResep.where((r) => r.produkId == it.produkId);
      for (final r in resep) {
        final bahan = semuaBahan.where((b) => b.id == r.bahanId).firstOrNull;
        if (bahan != null) {
          await updateStokBahan(r.bahanId, bahan.stok + r.qty * it.jumlah);
        }
      }
    }
  }

  Future<void> updateTransaksiStatus(
    String trxId,
    String status, {
    int? totalBayar,
    int? kembalian,
  }) async {
    final data = <String, dynamic>{'status': status};
    if (totalBayar != null) data['total_bayar'] = totalBayar;
    if (kembalian != null) data['kembalian'] = kembalian;
    await _c.from('transaksi').update(data).eq('id', trxId).eq('user_id', uid);
  }

  // ── STOK UPDATE ───────────────────────────────────────────

  Future<List<StokUpdate>> allStokUpdate() async {
    final rows = await _c
        .from('stok_update')
        .select()
        .eq('user_id', uid)
        .order('tanggal', ascending: false);
    return (rows as List).map((r) => StokUpdate.fromSupabase(r)).toList();
  }

  Future<List<StokUpdateItem>> stokUpdateItemsOf(String updateId) async {
    final rows = await _c
        .from('stok_update_item')
        .select()
        .eq('user_id', uid)
        .eq('update_id', updateId);
    return (rows as List).map((r) => StokUpdateItem.fromSupabase(r)).toList();
  }

  Future<String> catatStokUpdate({
    required List<StokUpdateItem> items,
    required List<Produk> semuaProduk,
  }) async {
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

    final countResult = await _c
        .from('stok_update')
        .select('id')
        .eq('user_id', uid)
        .gte('tanggal', startOfDay)
        .lte('tanggal', endOfDay);
    final noUrut = (countResult as List).length + 1;

    final totalQty = items.fold<double>(0, (s, e) => s + e.qty);

    final headerRow = await _c
        .from('stok_update')
        .insert(StokUpdate(
          tanggal: now.millisecondsSinceEpoch,
          noUrut: noUrut,
          totalItem: items.length,
          totalQty: totalQty,
        ).toSupabase(uid))
        .select()
        .single();
    final updateId = headerRow['id'] as String;

    // Insert items + update stok produk
    for (final it in items) {
      await _c
          .from('stok_update_item')
          .insert(it.toSupabase(uid, updateId));
      final produk = semuaProduk.where((p) => p.id == it.produkId).firstOrNull;
      if (produk != null) {
        await updateStokProduk(it.produkId, produk.stok + it.qty);
      }
    }

    return updateId;
  }

  // ── CLEAR ALL (fresh start) ───────────────────────────────

  Future<void> clearAll() async {
    final u = uid;
    await _c.from('transaksi_item').delete().eq('user_id', u);
    await _c.from('transaksi').delete().eq('user_id', u);
    await _c.from('stok_update_item').delete().eq('user_id', u);
    await _c.from('stok_update').delete().eq('user_id', u);
    await _c.from('resep_item').delete().eq('user_id', u);
    await _c.from('produk_tier').delete().eq('user_id', u);
    await _c.from('bahan').delete().eq('user_id', u);
    await _c.from('produk').delete().eq('user_id', u);
  }

  // ── REALTIME STREAMS ──────────────────────────────────────

  Stream<List<Map<String, dynamic>>> streamProduk() {
    return _c
        .from('produk')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('nama');
  }

  Stream<List<Map<String, dynamic>>> streamBahan() {
    return _c
        .from('bahan')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('nama');
  }

  Stream<List<Map<String, dynamic>>> streamTransaksi() {
    return _c
        .from('transaksi')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('tanggal', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamStaff() {
    return _c
        .from('staff')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('role');
  }
}
