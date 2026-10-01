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

  /// true = harga modal dihitung dari resep HPP
  final bool gunakanHpp;

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
    this.gunakanHpp = false,
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
    bool? gunakanHpp,
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
      gunakanHpp: gunakanHpp ?? this.gunakanHpp,
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
        'gunakanHpp': gunakanHpp ? 1 : 0,
      };

  factory Produk.fromMap(Map<String, dynamic> m) => Produk(
        id: m['id'] as int?,
        nama: m['nama'] as String,
        satuan: (m['satuan'] as String?) ?? 'pcs',
        barcode: m['barcode'] as String?,
        hargaModal: (m['hargaModal'] as num?)?.toInt() ?? 0,
        harga: (m['harga'] as num).toInt(),
        stok: (m['stok'] as num).toDouble(),
        foto: m['foto'] as String?,
        kategori: m['kategori'] as String?,
        gunakanHpp: ((m['gunakanHpp'] as num?)?.toInt() ?? 0) == 1,
      );
}

/// Bahan baku (terpisah dari produk jual)
class Bahan {
  final int? id;
  final String nama;
  final String satuan; // g, ml, pcs, kg, ...
  /// Harga beli untuk [jumlahBeli] satuan (mis. 10 kg = 10000)
  final int hargaBeli;

  /// Jumlah satuan saat beli (mis. 10 untuk 10 kg, 100 untuk 100 ml)
  final double jumlahBeli;

  /// Stok sisa dalam satuan dasar (g, ml, pcs)
  final double stok;

  const Bahan({
    this.id,
    required this.nama,
    this.satuan = 'g',
    this.hargaBeli = 0,
    this.jumlahBeli = 1,
    this.stok = 0,
  });

  /// Harga per 1 satuan (dibulatkan ke int rupiah)
  int get hargaPerSatuan {
    if (jumlahBeli <= 0) return 0;
    return (hargaBeli / jumlahBeli).round();
  }

  Bahan copyWith({
    int? id,
    String? nama,
    String? satuan,
    int? hargaBeli,
    double? jumlahBeli,
    double? stok,
  }) {
    return Bahan(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      satuan: satuan ?? this.satuan,
      hargaBeli: hargaBeli ?? this.hargaBeli,
      jumlahBeli: jumlahBeli ?? this.jumlahBeli,
      stok: stok ?? this.stok,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nama': nama,
        'satuan': satuan,
        'hargaBeli': hargaBeli,
        'jumlahBeli': jumlahBeli,
        'stok': stok,
      };

  factory Bahan.fromMap(Map<String, dynamic> m) => Bahan(
        id: m['id'] as int?,
        nama: m['nama'] as String,
        satuan: (m['satuan'] as String?) ?? 'g',
        hargaBeli: (m['hargaBeli'] as num?)?.toInt() ?? 0,
        jumlahBeli: (m['jumlahBeli'] as num?)?.toDouble() ?? 1,
        stok: (m['stok'] as num?)?.toDouble() ?? 0,
      );
}

/// Satu baris resep: produk X memakai [qty] satuan [bahanId]
class ResepItem {
  final int? id;
  final int produkId;
  final int bahanId;
  final double qty;

  const ResepItem({
    this.id,
    required this.produkId,
    required this.bahanId,
    required this.qty,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'produkId': produkId,
        'bahanId': bahanId,
        'qty': qty,
      };

  factory ResepItem.fromMap(Map<String, dynamic> m) => ResepItem(
        id: m['id'] as int?,
        produkId: (m['produkId'] as num).toInt(),
        bahanId: (m['bahanId'] as num).toInt(),
        qty: (m['qty'] as num).toDouble(),
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
        id: m['id'] as int?,
        tanggal: (m['tanggal'] as num).toInt(),
        totalBelanja: (m['totalBelanja'] as num).toInt(),
        totalBayar: (m['totalBayar'] as num).toInt(),
        kembalian: (m['kembalian'] as num).toInt(),
        noUrut: (m['noUrut'] as num?)?.toInt() ?? 0,
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
        id: m['id'] as int?,
        transaksiId: (m['transaksiId'] as num).toInt(),
        produkId: (m['produkId'] as num).toInt(),
        namaProduk: m['namaProduk'] as String,
        hargaModal: (m['hargaModal'] as num?)?.toInt() ?? 0,
        hargaSatuan: (m['hargaSatuan'] as num).toInt(),
        jumlah: (m['jumlah'] as num).toDouble(),
        subtotal: (m['subtotal'] as num).toInt(),
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
        id: m['id'] as int?,
        produkId: (m['produkId'] as num?)?.toInt() ?? 0,
        minQty: (m['minQty'] as num?)?.toDouble() ?? 1,
        harga: (m['harga'] as num?)?.toInt() ?? 0,
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

/// Akun staff (Manager / Admin / Kasir)
class Staff {
  final int? id;
  final String nama;
  final String pin;

  /// Manager | Admin | Kasir
  final String role;
  final bool aktif;

  /// Menu yang boleh dibuka (khusus non-Manager).
  /// Key: pos, produk, laporan, staff, printer, backup, settings, license
  final List<String> permissions;

  const Staff({
    this.id,
    required this.nama,
    required this.pin,
    required this.role,
    this.aktif = true,
    this.permissions = const [],
  });

  bool get isManager => role == 'Manager';

  Staff copyWith({
    int? id,
    String? nama,
    String? pin,
    String? role,
    bool? aktif,
    List<String>? permissions,
  }) {
    return Staff(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      aktif: aktif ?? this.aktif,
      permissions: permissions ?? this.permissions,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nama': nama,
        'pin': pin,
        'role': role,
        'aktif': aktif ? 1 : 0,
        'permissions': permissions.join(','),
      };

  factory Staff.fromMap(Map<String, dynamic> m) {
    final raw = (m['permissions'] as String?) ?? '';
    final perms = raw.isEmpty
        ? <String>[]
        : raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    return Staff(
      id: m['id'] as int?,
      nama: m['nama'] as String,
      pin: m['pin'] as String,
      role: m['role'] as String,
      aktif: ((m['aktif'] as num?)?.toInt() ?? 1) == 1,
      permissions: perms,
    );
  }

  /// Default permission per role
  static List<String> defaultPermissions(String role) {
    switch (role) {
      case 'Manager':
        return const [
          'pos',
          'produk',
          'laporan',
          'staff',
          'printer',
          'backup',
          'settings',
          'license'
        ];
      case 'Admin':
        return const ['pos', 'produk', 'laporan', 'printer', 'settings'];
      case 'Kasir':
      default:
        return const ['pos', 'printer'];
    }
  }
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
        id: m['id'] as int?,
        tanggal: (m['tanggal'] as num).toInt(),
        noUrut: (m['noUrut'] as num).toInt(),
        totalItem: (m['totalItem'] as num).toInt(),
        totalQty: (m['totalQty'] as num).toDouble(),
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
        id: m['id'] as int?,
        updateId: (m['updateId'] as num).toInt(),
        produkId: (m['produkId'] as num).toInt(),
        namaProduk: (m['namaProduk'] as String?) ?? '',
        qty: (m['qty'] as num).toDouble(),
        stokSebelum: (m['stokSebelum'] as num).toDouble(),
        stokSesudah: (m['stokSesudah'] as num).toDouble(),
      );
}
