/// Baris dari sqflite selalu int/double, tapi backup versi online membawa
/// angka sebagai string (mis. id "770") karena dijawab lewat API. Semua
/// fromMap memakai dua fungsi ini supaya kedua format file bisa dibaca.
int? asIntOrNull(dynamic v) {
  if (v == null || v is String) return int.tryParse('${v ?? ''}'.trim());
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}

double? asDoubleOrNull(dynamic v) {
  if (v == null || v is String) return double.tryParse('${v ?? ''}'.trim());
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return null;
}

/// Kolom wajib: gagal dengan nama kolom daripada menyimpan 0 diam-diam.
Never badValue(String field, dynamic v) =>
    throw FormatException('Kolom "$field" bukan angka: $v');

int asInt(dynamic v, String field) => asIntOrNull(v) ?? badValue(field, v);

double asDouble(dynamic v, String field) =>
    asDoubleOrNull(v) ?? badValue(field, v);

class Produk {
  final int? id;
  final String nama;
  final String satuan;
  final String? barcode;
  final int hargaModal;
  final int harga;
  final double stok;
  final String? foto;
  final String? kategori;

  const Produk({
    this.id,
    required this.nama,
    this.satuan = 'pcs',
    this.barcode,
    this.hargaModal = 0,
    required this.harga,
    required this.stok,
    this.foto,
    this.kategori,
  });

  Produk copyWith({
    int? id,
    String? nama,
    String? satuan,
    String? barcode,
    int? hargaModal,
    int? harga,
    double? stok,
    String? foto,
    String? kategori,
    bool clearKategori = false,
  }) {
    return Produk(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      satuan: satuan ?? this.satuan,
      barcode: barcode ?? this.barcode,
      hargaModal: hargaModal ?? this.hargaModal,
      harga: harga ?? this.harga,
      stok: stok ?? this.stok,
      foto: foto ?? this.foto,
      kategori: clearKategori ? null : (kategori ?? this.kategori),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nama': nama,
        'satuan': satuan,
        'barcode': barcode,
        'hargaModal': hargaModal,
        'harga': harga,
        'stok': stok,
        'foto': foto,
        'kategori': kategori,
      };

  factory Produk.fromMap(Map<String, dynamic> m) => Produk(
        id: asIntOrNull(m['id']),
        nama: m['nama'] as String,
        satuan: (m['satuan'] as String?) ?? 'pcs',
        barcode: m['barcode'] as String?,
        hargaModal: asIntOrNull(m['hargaModal']) ?? 0,
        harga: asInt(m['harga'], 'harga'),
        stok: asDouble(m['stok'], 'stok'),
        foto: m['foto'] as String?,
        kategori: m['kategori'] as String?,
      );
}


class Transaksi {
  final int? id;
  final int tanggal;
  final int totalBelanja;
  final int totalBayar;
  final int kembalian;
  final int noUrut; // Nomor urut harian
  final String metode; // 'cash' | 'qris' | 'transfer' | 'hutang'
  final String status; // 'selesai' | 'batal' | 'hutang'
  final String namaHutang; // nama orang yang berhutang (jika metode hutang)

  const Transaksi({
    this.id,
    required this.tanggal,
    required this.totalBelanja,
    required this.totalBayar,
    required this.kembalian,
    this.noUrut = 0,
    this.metode = 'cash',
    this.status = 'selesai',
    this.namaHutang = '',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'tanggal': tanggal,
        'totalBelanja': totalBelanja,
        'totalBayar': totalBayar,
        'kembalian': kembalian,
        'noUrut': noUrut,
        'metode': metode,
        'status': status,
        'namaHutang': namaHutang,
      };

  factory Transaksi.fromMap(Map<String, dynamic> m) => Transaksi(
        id: asIntOrNull(m['id']),
        tanggal: asInt(m['tanggal'], 'tanggal'),
        totalBelanja: asInt(m['totalBelanja'], 'totalBelanja'),
        totalBayar: asInt(m['totalBayar'], 'totalBayar'),
        kembalian: asInt(m['kembalian'], 'kembalian'),
        noUrut: asIntOrNull(m['noUrut']) ?? 0,
        metode: (m['metode'] as String?) ?? 'cash',
        status: (m['status'] as String?) ?? 'selesai',
        namaHutang: (m['namaHutang'] as String?) ?? '',
      );
}

class TransaksiItem {
  final int? id;
  final int transaksiId;
  final int produkId;
  final String namaProduk;
  final int hargaModal;
  final int hargaSatuan;
  final double jumlah;
  final int subtotal;

  const TransaksiItem({
    this.id,
    required this.transaksiId,
    required this.produkId,
    required this.namaProduk,
    this.hargaModal = 0,
    required this.hargaSatuan,
    required this.jumlah,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'transaksiId': transaksiId,
        'produkId': produkId,
        'namaProduk': namaProduk,
        'hargaModal': hargaModal,
        'hargaSatuan': hargaSatuan,
        'jumlah': jumlah,
        'subtotal': subtotal,
      };

  factory TransaksiItem.fromMap(Map<String, dynamic> m) => TransaksiItem(
        id: asIntOrNull(m['id']),
        transaksiId: asInt(m['transaksiId'], 'transaksiId'),
        produkId: asInt(m['produkId'], 'produkId'),
        namaProduk: m['namaProduk'] as String,
        hargaModal: asIntOrNull(m['hargaModal']) ?? 0,
        hargaSatuan: asInt(m['hargaSatuan'], 'hargaSatuan'),
        jumlah: asDouble(m['jumlah'], 'jumlah'),
        subtotal: asInt(m['subtotal'], 'subtotal'),
      );
}

/// Harga paket / grosir: [harga] adalah total untuk [minQty] unit.
/// Contoh: minQty=3, harga=10000 → beli 3 bayar 10000 (bukan 3×satuan).
class HargaTier {
  final int? id;
  final int produkId;
  final double minQty;
  final int harga;
  final String label;

  const HargaTier({
    this.id,
    this.produkId = 0,
    required this.minQty,
    required this.harga,
    this.label = '',
  });

  HargaTier copyWith({
    int? id,
    int? produkId,
    double? minQty,
    int? harga,
    String? label,
  }) =>
      HargaTier(
        id: id ?? this.id,
        produkId: produkId ?? this.produkId,
        minQty: minQty ?? this.minQty,
        harga: harga ?? this.harga,
        label: label ?? this.label,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'produkId': produkId,
        'minQty': minQty,
        'harga': harga,
        'label': label,
      };

  factory HargaTier.fromMap(Map<String, dynamic> m) => HargaTier(
        id: asIntOrNull(m['id']),
        produkId: asIntOrNull(m['produkId']) ?? 0,
        minQty: asDoubleOrNull(m['minQty']) ?? 1,
        harga: asIntOrNull(m['harga']) ?? 0,
        label: (m['label'] as String?) ?? '',
      );

  /// Hitung subtotal qty dengan paket terbesar dulu, sisa × harga satuan.
  static int lineTotal(double qty, int hargaSatuan, List<HargaTier> tiers) {
    if (qty <= 0) return 0;
    if (tiers.isEmpty) return (hargaSatuan * qty).round();
    final sorted = [...tiers]..sort((a, b) => b.minQty.compareTo(a.minQty));
    double left = qty;
    int total = 0;
    for (final t in sorted) {
      if (t.minQty <= 0 || t.harga <= 0) continue;
      final packs = (left / t.minQty).floor();
      if (packs > 0) {
        total += packs * t.harga;
        left -= packs * t.minQty;
      }
    }
    if (left > 0) total += (hargaSatuan * left).round();
    return total;
  }
}

class CartItem {
  final int produkId;
  final String nama;
  final String satuan;
  final int hargaModal;
  final int harga;
  final double qty;
  final double stokTersedia;

  /// Snapshot tier harga paket saat item masuk keranjang
  final List<HargaTier> tiers;

  const CartItem({
    required this.produkId,
    required this.nama,
    required this.satuan,
    required this.hargaModal,
    required this.harga,
    required this.qty,
    required this.stokTersedia,
    this.tiers = const [],
  });

  CartItem copyWith({double? qty, List<HargaTier>? tiers}) => CartItem(
        produkId: produkId,
        nama: nama,
        satuan: satuan,
        hargaModal: hargaModal,
        harga: harga,
        qty: qty ?? this.qty,
        stokTersedia: stokTersedia,
        tiers: tiers ?? this.tiers,
      );

  int get subtotal => HargaTier.lineTotal(qty, harga, tiers);
}

/// Header satu sesi update stok
class StokUpdate {
  final int? id;
  final int tanggal;
  final int noUrut;
  final int totalItem;
  final double totalQty;

  const StokUpdate({
    this.id,
    required this.tanggal,
    required this.noUrut,
    required this.totalItem,
    required this.totalQty,
  });

  String get kode {
    final n = noUrut.toString().padLeft(3, '0');
    return 'STK-$n';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'tanggal': tanggal,
        'noUrut': noUrut,
        'totalItem': totalItem,
        'totalQty': totalQty,
      };

  factory StokUpdate.fromMap(Map<String, dynamic> m) => StokUpdate(
        id: asIntOrNull(m['id']),
        tanggal: asInt(m['tanggal'], 'tanggal'),
        noUrut: asInt(m['noUrut'], 'noUrut'),
        totalItem: asInt(m['totalItem'], 'totalItem'),
        totalQty: asDouble(m['totalQty'], 'totalQty'),
      );
}

/// Detail item dalam sesi update stok
class StokUpdateItem {
  final int? id;
  final int updateId;
  final int produkId;
  final String namaProduk;
  final double qty;
  final double stokSebelum;
  final double stokSesudah;

  const StokUpdateItem({
    this.id,
    this.updateId = 0,
    required this.produkId,
    required this.namaProduk,
    required this.qty,
    required this.stokSebelum,
    required this.stokSesudah,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'updateId': updateId,
        'produkId': produkId,
        'namaProduk': namaProduk,
        'qty': qty,
        'stokSebelum': stokSebelum,
        'stokSesudah': stokSesudah,
      };

  factory StokUpdateItem.fromMap(Map<String, dynamic> m) => StokUpdateItem(
        id: asIntOrNull(m['id']),
        updateId: asInt(m['updateId'], 'updateId'),
        produkId: asInt(m['produkId'], 'produkId'),
        namaProduk: (m['namaProduk'] as String?) ?? '',
        qty: asDouble(m['qty'], 'qty'),
        stokSebelum: asDouble(m['stokSebelum'], 'stokSebelum'),
        stokSesudah: asDouble(m['stokSesudah'], 'stokSesudah'),
      );
}
