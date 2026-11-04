import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db.dart';
import '../models/models.dart';
import '../services/printer_service.dart';
import '../services/backup_service.dart';

class App extends ChangeNotifier {
  final _db = Db.i;

  List<Produk> produk = [];

  /// harga paket/grosir per produkId
  Map<int, List<HargaTier>> tierMap = {};
  List<Transaksi> transaksi = [];
  List<TransaksiItem> allItems = [];
  final Map<int, CartItem> cart = {};

  /// Draft list Update Stok (persisten saat pindah menu)
  final Map<int, double> pendingStok = {};
  List<StokUpdate> stokUpdates = [];

  String tab = 'POS';
  bool navExpanded = false;
  // Track perubahan navExpanded agar animasi hanya jalan saat nilai berubah
  bool navExpandedChanged = false;

  /// Rail kiri tablet/PC - disimpan di provider agar tidak reset
  bool railExpanded = false;
  bool sheetOpen = false;

  // Store settings
  String storeName = 'Ngical';
  String storeAddress = '';
  String storePhone = '';
  String ownerName = 'Owner';
  String storeLogo = ''; // file path
  // Payment settings
  String qrisToken = '';
  String bankName = '';
  String noRekening = '';
  String atasNama = '';
  // Printer settings
  String printerType = 'bluetooth';
  String printerIp = '';
  String printerPort = '9100';
  String printerPaperWidth = '58';
  bool printerAutoPrint = false;
  bool printerPrintLogo = true;
  bool printerPrintFooter = true;
  String printerBluetoothMac =
      ''; // mac address printer BT yang dipilih di halaman Printer
  String printerBluetoothName = '';

  /// Nama / URL printer sistem (Windows/macOS/Linux) yang dipilih.
  /// Kosong = masih pakai dialog print sistem.
  String printerWindowsName = '';
  String printerWindowsUrl = '';
  // Jadwal backup otomatis
  bool backupAutoEnabled = false;
  String backupFrequency = 'daily'; // daily | weekly
  int backupWeekday = DateTime.monday; // 1-7, dipakai kalau weekly
  int backupHour = 22;
  int backupMinute = 0;
  String backupScope = 'all'; // all | produk
  int backupLastRunAt = 0; // millisecondsSinceEpoch, 0 = belum pernah
  String backupLastError = '';

  double get cartQty => cart.values.fold(0.0, (s, e) => s + e.qty);
  int get cartTotal => cart.values.fold(0, (s, e) => s + e.subtotal);
  int get totalPendapatan => transaksi
      .where((t) => t.status == 'selesai')
      .fold(0, (s, t) => s + t.totalBelanja);
  int get totalModal =>
      allItems.fold(0, (s, i) => s + (i.hargaModal * i.jumlah).round());
  int get pendapatanBersih => totalPendapatan - totalModal;

  /// Daftar kategori unik dari semua produk, terurut A-Z, tanpa null/kosong.
  List<String> get uniqueKategori {
    final set = <String>{};
    for (final p in produk) {
      if (p.kategori != null && p.kategori!.trim().isNotEmpty) {
        set.add(p.kategori!.trim());
      }
    }
    return set.toList()..sort();
  }

  Future<void> init() async {
    await _loadSettings();
    await refreshProduk();
    await refreshTiers();
    await refreshStokUpdate();
    await refreshTrx();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    storeName = prefs.getString('storeName') ?? storeName;
    storeAddress = prefs.getString('storeAddress') ?? storeAddress;
    storePhone = prefs.getString('storePhone') ?? storePhone;
    ownerName = prefs.getString('ownerName') ?? ownerName;
    storeLogo = prefs.getString('storeLogo') ?? storeLogo;
    qrisToken = prefs.getString('qrisToken') ?? qrisToken;
    bankName = prefs.getString('bankName') ?? bankName;
    noRekening = prefs.getString('noRekening') ?? noRekening;
    atasNama = prefs.getString('atasNama') ?? atasNama;
    printerType = prefs.getString('printerType') ?? printerType;
    printerIp = prefs.getString('printerIp') ?? printerIp;
    printerPort = prefs.getString('printerPort') ?? printerPort;
    printerPaperWidth =
        prefs.getString('printerPaperWidth') ?? printerPaperWidth;
    printerAutoPrint = prefs.getBool('printerAutoPrint') ?? printerAutoPrint;
    printerPrintLogo = prefs.getBool('printerPrintLogo') ?? printerPrintLogo;
    printerPrintFooter =
        prefs.getBool('printerPrintFooter') ?? printerPrintFooter;
    printerBluetoothMac =
        prefs.getString('printerBluetoothMac') ?? printerBluetoothMac;
    printerBluetoothName =
        prefs.getString('printerBluetoothName') ?? printerBluetoothName;
    printerWindowsName =
        prefs.getString('printerWindowsName') ?? printerWindowsName;
    printerWindowsUrl =
        prefs.getString('printerWindowsUrl') ?? printerWindowsUrl;
    backupAutoEnabled = prefs.getBool('backupAutoEnabled') ?? backupAutoEnabled;
    backupFrequency = prefs.getString('backupFrequency') ?? backupFrequency;
    backupWeekday = prefs.getInt('backupWeekday') ?? backupWeekday;
    backupHour = prefs.getInt('backupHour') ?? backupHour;
    backupMinute = prefs.getInt('backupMinute') ?? backupMinute;
    backupScope = prefs.getString('backupScope') ?? backupScope;
    backupLastRunAt = prefs.getInt('backupLastRunAt') ?? backupLastRunAt;
    backupLastError = prefs.getString('backupLastError') ?? backupLastError;
    notifyListeners();
  }

  Future<void> saveSettings({
    String? name,
    String? address,
    String? phone,
    String? owner,
    String? logo,
    String? qris,
    String? bank,
    String? rek,
    String? atNama,
  }) async {
    if (name != null) storeName = name;
    if (address != null) storeAddress = address;
    if (phone != null) storePhone = phone;
    if (owner != null) ownerName = owner;
    if (logo != null) storeLogo = logo;
    if (qris != null) qrisToken = qris;
    if (bank != null) bankName = bank;
    if (rek != null) noRekening = rek;
    if (atNama != null) atasNama = atNama;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('storeName', storeName);
    await prefs.setString('storeAddress', storeAddress);
    await prefs.setString('storePhone', storePhone);
    await prefs.setString('ownerName', ownerName);
    await prefs.setString('storeLogo', storeLogo);
    await prefs.setString('qrisToken', qrisToken);
    await prefs.setString('bankName', bankName);
    await prefs.setString('noRekening', noRekening);
    await prefs.setString('atasNama', atasNama);
  }

  // Keep backward compat
  void updateStore(
      {String? name, String? address, String? phone, String? owner}) {
    saveSettings(name: name, address: address, phone: phone, owner: owner);
  }

  Future<void> savePrinterSettings({
    String? type,
    String? ip,
    String? port,
    bool? autoPrint,
    String? paperWidth,
    bool? printLogo,
    bool? printFooter,
    String? bluetoothMac,
    String? bluetoothName,
    String? windowsName,
    String? windowsUrl,
  }) async {
    if (type != null) printerType = type;
    if (ip != null) printerIp = ip;
    if (port != null) printerPort = port;
    if (autoPrint != null) printerAutoPrint = autoPrint;
    if (paperWidth != null) printerPaperWidth = paperWidth;
    if (printLogo != null) printerPrintLogo = printLogo;
    if (printFooter != null) printerPrintFooter = printFooter;
    if (bluetoothMac != null) printerBluetoothMac = bluetoothMac;
    if (bluetoothName != null) printerBluetoothName = bluetoothName;
    if (windowsName != null) printerWindowsName = windowsName;
    if (windowsUrl != null) printerWindowsUrl = windowsUrl;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printerType', printerType);
    await prefs.setString('printerIp', printerIp);
    await prefs.setString('printerPort', printerPort);
    await prefs.setString('printerPaperWidth', printerPaperWidth);
    await prefs.setBool('printerAutoPrint', printerAutoPrint);
    await prefs.setBool('printerPrintLogo', printerPrintLogo);
    await prefs.setBool('printerPrintFooter', printerPrintFooter);
    await prefs.setString('printerBluetoothMac', printerBluetoothMac);
    await prefs.setString('printerBluetoothName', printerBluetoothName);
    await prefs.setString('printerWindowsName', printerWindowsName);
    await prefs.setString('printerWindowsUrl', printerWindowsUrl);
  }

  Future<void> saveBackupSchedule({
    bool? enabled,
    String? frequency,
    int? weekday,
    int? hour,
    int? minute,
    String? scope,
  }) async {
    if (enabled != null) backupAutoEnabled = enabled;
    if (frequency != null) backupFrequency = frequency;
    if (weekday != null) backupWeekday = weekday;
    if (hour != null) backupHour = hour;
    if (minute != null) backupMinute = minute;
    if (scope != null) backupScope = scope;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('backupAutoEnabled', backupAutoEnabled);
    await prefs.setString('backupFrequency', backupFrequency);
    await prefs.setInt('backupWeekday', backupWeekday);
    await prefs.setInt('backupHour', backupHour);
    await prefs.setInt('backupMinute', backupMinute);
    await prefs.setString('backupScope', backupScope);
  }

  /// Waktu "seharusnya sudah backup" yang paling baru, dihitung mundur
  /// dari sekarang berdasarkan frequency/weekday/jam/menit yang tersimpan.
  DateTime _lastDueSlot() {
    final now = DateTime.now();
    DateTime todayAt(DateTime d) =>
        DateTime(d.year, d.month, d.day, backupHour, backupMinute);

    if (backupFrequency == 'weekly') {
      var candidate = todayAt(now);
      // Mundur ke weekday yang dipilih (maksimal 7 hari ke belakang)
      for (int i = 0; i < 7; i++) {
        if (candidate.weekday == backupWeekday && !candidate.isAfter(now)) {
          return candidate;
        }
        candidate = candidate.subtract(const Duration(days: 1));
      }
      return candidate;
    }

    // daily
    var slot = todayAt(now);
    if (slot.isAfter(now)) slot = slot.subtract(const Duration(days: 1));
    return slot;
  }

  /// Dipanggil saat app dibuka & saat app ditutup/diminimize.
  /// Kalau jadwal aktif dan slot terakhir belum pernah ke-backup,
  /// jalankan backup sekarang di background (tidak mengganggu UI,
  /// dan tidak pernah melempar error ke pemanggil).
  Future<void> checkAndRunScheduledBackupIfDue() async {
    if (!backupAutoEnabled) return;
    final due = _lastDueSlot();
    if (backupLastRunAt >= due.millisecondsSinceEpoch) {
      return; // sudah pernah utk slot ini
    }

    try {
      await refreshProduk();
      await refreshTrx();
      await runAutoBackup(this, scope: backupScope);
      backupLastError = '';
    } catch (e) {
      backupLastError = e.toString();
      // Sengaja TIDAK update backupLastRunAt kalau gagal, supaya
      // dicoba lagi di kesempatan berikutnya (buka/tutup app lagi).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backupLastError', backupLastError);
      notifyListeners();
      return;
    }

    backupLastRunAt = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('backupLastRunAt', backupLastRunAt);
    await prefs.setString('backupLastError', '');
    notifyListeners();
  }

  Map<String, String> settingsMap() => {
        'storeName': storeName,
        'storeAddress': storeAddress,
        'storePhone': storePhone,
        'ownerName': ownerName,
        'storeLogo': storeLogo,
        'qrisToken': qrisToken,
        'bankName': bankName,
        'noRekening': noRekening,
        'atasNama': atasNama,
      };

  Future<void> restoreSettings(Map<String, dynamic> map) async {
    await saveSettings(
      name: map['storeName'] as String?,
      address: map['storeAddress'] as String?,
      phone: map['storePhone'] as String?,
      owner: map['ownerName'] as String?,
      qris: map['qrisToken'] as String?,
      bank: map['bankName'] as String?,
      rek: map['noRekening'] as String?,
      atNama: map['atasNama'] as String?,
    );
  }

  Future<void> refreshProduk() async {
    produk = await _db.allProduk();
    notifyListeners();
  }

  Future<void> refreshTiers() async {
    try {
      final all = await _db.allTiers();
      final map = <int, List<HargaTier>>{};
      for (final t in all) {
        map.putIfAbsent(t.produkId, () => []).add(t);
      }
      for (final list in map.values) {
        list.sort((a, b) => a.minQty.compareTo(b.minQty));
      }
      tierMap = map;
    } catch (_) {
      // Tabel belum ada / migrasi gagal → jangan blokir UI
      tierMap = {};
    }
    notifyListeners();
  }

  List<HargaTier> tiersOf(int produkId) =>
      List<HargaTier>.from(tierMap[produkId] ?? const []);

  Future<void> refreshTrx() async {
    transaksi = await _db.allTransaksi();
    allItems = await _db.allItems();
    notifyListeners();
  }

  void setTab(String t) {
    tab = t;
    notifyListeners();
  }

  void setRailExpanded(bool v) {
    if (railExpanded == v) return;
    railExpanded = v;
    notifyListeners();
  }

  void toggleRailExpanded() {
    railExpanded = !railExpanded;
    notifyListeners();
  }

  void expandNav() {
    if (sheetOpen) return;
    navExpanded = true;
    navExpandedChanged = true;
    notifyListeners();
  }

  void collapseNav() {
    navExpanded = false;
    navExpandedChanged = true;
    notifyListeners();
  }

  /// Dipanggil oleh widget setelah membaca navExpandedChanged
  void consumeNavChange() {
    navExpandedChanged = false;
  }

  void setSheet(bool open) {
    sheetOpen = open;
    // Jangan paksa collapse navExpanded saat buka sheet (keranjang),
    // supaya setelah sheet ditutup posisi expand/collapse tetap seperti sebelumnya.
    notifyListeners();
  }

  /// false = ditolak karena stok habis atau produk invalid
  bool addCart(Produk p) {
    if (p.id == null || p.stok <= 0) return false;
    final e = cart[p.id!];
    if (e != null) {
      if (e.qty >= p.stok) return false;
      cart[p.id!] = e.copyWith(qty: e.qty + 1);
    } else {
      cart[p.id!] = CartItem(
        produkId: p.id!,
        nama: p.nama,
        satuan: p.satuan,
        hargaModal: p.hargaModal,
        harga: p.harga,
        qty: 1,
        stokTersedia: p.stok,
        tiers: tiersOf(p.id!),
      );
    }
    notifyListeners();
    return true;
  }

  void updateCartQty(int id, double newQty) {
    final e = cart[id];
    if (e == null) return;
    if (newQty <= 0) {
      cart.remove(id);
    } else {
      // Limit to stock if needed, or allow negative/unlimited if you want
      final finalQty = newQty > e.stokTersedia ? e.stokTersedia : newQty;
      cart[id] = e.copyWith(qty: finalQty);
    }
    notifyListeners();
  }

  bool addCartByBarcode(String barcode) {
    final matches = produk
        .where(
          (p) =>
              p.barcode != null &&
              p.barcode!.toLowerCase() == barcode.toLowerCase(),
        )
        .toList();
    if (matches.isNotEmpty) return addCart(matches.first);
    return false;
  }

  void decCart(int id) {
    final e = cart[id];
    if (e == null) return;
    if (e.qty <= 1) {
      cart.remove(id);
    } else {
      cart[id] = e.copyWith(qty: e.qty - 1);
    }
    notifyListeners();
  }

  void removeCart(int id) {
    cart.remove(id);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  Future<int?> bayar(
    int tunai, {
    String metode = 'cash',
    String status = 'selesai',
    String namaHutang = '',
  }) async {
    if (cart.isEmpty) return null;
    final total = cartTotal;
    // Hutang: bayar 0 dulu, status hutang. Cash: harus cukup.
    if (status != 'hutang' && tunai < total) return null;
    final bayarAmount = status == 'hutang' ? 0 : tunai;
    final kembali = status == 'hutang' ? 0 : (tunai - total);
    final cartSnapshot = cart.values.toList();

    await _db.catatTransaksi(
      transaksi: Transaksi(
        tanggal: DateTime.now().millisecondsSinceEpoch,
        totalBelanja: total,
        totalBayar: bayarAmount,
        kembalian: kembali,
        metode: metode,
        status: status,
        namaHutang: namaHutang,
      ),
      items: cartSnapshot
          .map((c) => TransaksiItem(
                transaksiId: 0,
                produkId: c.produkId,
                namaProduk: c.nama,
                hargaModal: c.hargaModal,
                hargaSatuan: c.harga,
                jumlah: c.qty,
                subtotal: c.subtotal,
              ))
          .toList(),
    );

    clearCart();
    await refreshProduk();
    await refreshTrx();

    // Hutang tidak auto-print ke laporan keuangan; struk opsional tetap boleh
    if (printerAutoPrint && status != 'hutang') {
      unawaited(cetakStruk(
        items: cartSnapshot
            .map((c) => ReceiptLine(
                nama: c.nama, qty: c.qty, harga: c.harga, subtotal: c.subtotal))
            .toList(),
        total: total,
        bayar: bayarAmount,
        kembalian: kembali,
        metode: metode,
      ));
    }
    return kembali;
  }

  /// Tandai hutang sebagai lunas → masuk laporan (status selesai).
  Future<void> lunasHutang(int trxId, {int? totalBayar}) async {
    final trx = transaksi.where((t) => t.id == trxId).firstOrNull;
    if (trx == null || trx.status != 'hutang') return;
    final bayar = totalBayar ?? trx.totalBelanja;
    await _db.updateTransaksiStatus(
      trxId,
      'selesai',
      totalBayar: bayar,
      kembalian: bayar - trx.totalBelanja,
    );
    await refreshTrx();
  }

  /// Susun & kirim struk ke printer sesuai pengaturan yang tersimpan
  /// (printerType: bluetooth/wifi, printerPaperWidth, dll).
  /// Dipanggil otomatis dari [bayar] kalau [printerAutoPrint] aktif,
  /// atau bisa dipanggil manual (mis. tombol "Cetak Ulang" di riwayat).
  Future<PrintResult> cetakStruk({
    required List<ReceiptLine> items,
    required int total,
    required int bayar,
    required int kembalian,
    required String metode,
  }) async {
    final trxNo = transaksi.isNotEmpty ? '#${transaksi.first.noUrut}' : '-';
    final now = DateTime.now();
    const footer = 'Terima kasih telah berbelanja!';

    // Windows / printer sistem: PDF. Kalau printer sudah dipilih di setting,
    // cetak langsung tanpa dialog. Kalau belum, buka dialog seperti biasa.
    if (printerType == 'windows' || printerType == 'system') {
      final doc = await PrinterService.i.buildReceiptPdf(
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        printFooter: printerPrintFooter,
        footerText: footer,
        items: items,
        total: total,
        bayar: bayar,
        kembalian: kembalian,
        metode: metode,
        trxNo: trxNo,
        tanggal: now,
        paperWidthMm: printerPaperWidth,
        qrisToken: metode.toLowerCase() == 'qris' ? qrisToken : '',
      );
      return PrinterService.i.printWindowsSystem(
        doc,
        printerName: printerWindowsName,
        printerUrl: printerWindowsUrl,
        paperWidthMm: printerPaperWidth,
      );
    }

    final bytes = await PrinterService.i.buildReceiptBytes(
      paperWidthMm: printerPaperWidth,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      printLogo: printerPrintLogo,
      printFooter: printerPrintFooter,
      footerText: footer,
      items: items,
      total: total,
      bayar: bayar,
      kembalian: kembalian,
      metode: metode,
      trxNo: trxNo,
      tanggal: now,
      qrisToken: metode.toLowerCase() == 'qris' ? qrisToken : '',
    );

    if (printerType == 'wifi') {
      return PrinterService.i
          .printWifi(ip: printerIp, port: printerPort, bytes: bytes);
    }
    if (printerType == 'bluetooth') {
      if (printerBluetoothMac.isEmpty) {
        return const PrintResult(
            false, 'Belum pilih printer Bluetooth di Pengaturan Printer');
      }
      final connected = await PrinterService.i.isBluetoothConnected;
      if (!connected) {
        final ok = await PrinterService.i.connectBluetooth(printerBluetoothMac);
        if (!ok) {
          return const PrintResult(
              false, 'Gagal terhubung ke printer Bluetooth');
        }
      }
      return PrinterService.i.printBluetooth(bytes);
    }
    return const PrintResult(false, 'Tipe printer USB belum didukung');
  }

  /// Batalkan transaksi  kembalikan stok produk + bahan
  Future<void> cancelTransaksi(int trxId) async {
    await _db.cancelTransaksi(trxId);
    await refreshProduk();
    await refreshTrx();
  }

  /// Muat item transaksi ke keranjang untuk diedit ulang
  Future<void> editTransaksi(int trxId) async {
    final items = await _db.itemsOf(trxId);
    cart.clear();
    for (final item in items) {
      final produkMatch = produk.where((p) => p.id == item.produkId).toList();
      final stokTersedia = produkMatch.isNotEmpty ? produkMatch.first.stok : 0;
      cart[item.produkId] = CartItem(
        produkId: item.produkId,
        nama: item.namaProduk,
        satuan: produkMatch.isNotEmpty ? produkMatch.first.satuan : 'pcs',
        hargaModal: item.hargaModal,
        harga: item.hargaSatuan,
        qty: item.jumlah,
        stokTersedia:
            stokTersedia + item.jumlah, // stok saat ini + yang diambil
        tiers: tiersOf(item.produkId),
      );
    }
    notifyListeners();
  }

  Future<void> saveProduk(Produk p, {List<HargaTier>? tiers}) async {
    int id;
    final toSave = p;
    if (toSave.id == null) {
      id = await _db.insertProduk(toSave);
    } else {
      id = toSave.id!;
      await _db.updateProduk(toSave);
    }
    if (tiers != null) {
      await _db.setTiers(id, tiers);
      await refreshTiers();
    }
    await refreshProduk();
  }

  Future<void> deleteProduk(int id) async {
    await _db.deleteTiersOf(id);
    await _db.deleteProduk(id);
    await refreshTiers();
    await refreshProduk();
  }

  /// Tambah stok produk cepat (tanpa buka form edit).
  /// [qty] harus > 0. Mengembalikan stok baru, atau null jika gagal.
  Future<double?> tambahStokProduk(int produkId, double qty) async {
    if (qty <= 0) return null;
    final match = produk.where((e) => e.id == produkId).toList();
    if (match.isEmpty) return null;
    await _db.tambahStok(produkId, qty);
    await refreshProduk();
    final updated = produk.where((e) => e.id == produkId).toList();
    return updated.isEmpty ? null : updated.first.stok;
  }

  void setPendingStokQty(int produkId, double qty) {
    if (qty <= 0) {
      pendingStok.remove(produkId);
    } else {
      pendingStok[produkId] = qty;
    }
    notifyListeners();
  }

  void addPendingStok(int produkId, [double delta = 1]) {
    final q = (pendingStok[produkId] ?? 0) + delta;
    setPendingStokQty(produkId, q);
  }

  void clearPendingStok() {
    pendingStok.clear();
    notifyListeners();
  }

  Future<void> refreshStokUpdate() async {
    try {
      stokUpdates = await _db.allStokUpdate();
    } catch (_) {
      stokUpdates = [];
    }
    notifyListeners();
  }

  Future<List<StokUpdateItem>> stokUpdateItemsOf(int id) =>
      _db.stokUpdateItemsOf(id);

  /// Simpan draft pendingStok ke DB + history. Return jumlah item, 0 jika gagal.
  Future<int> simpanPendingStok() async {
    if (pendingStok.isEmpty) return 0;
    final items = <StokUpdateItem>[];
    for (final e in pendingStok.entries) {
      if (e.value <= 0) continue;
      final match = produk.where((p) => p.id == e.key).toList();
      if (match.isEmpty) continue;
      final p = match.first;
      items.add(StokUpdateItem(
        produkId: e.key,
        namaProduk: p.nama,
        qty: e.value,
        stokSebelum: p.stok,
        stokSesudah: p.stok + e.value,
      ));
    }
    if (items.isEmpty) return 0;
    await _db.catatStokUpdate(items: items);
    pendingStok.clear();
    await refreshProduk();
    await refreshStokUpdate();
    return items.length;
  }

  /// Batch update stok tanpa history (legacy). Prefer simpanPendingStok.
  Future<int> tambahStokBatch(Map<int, double> items) async {
    var n = 0;
    for (final e in items.entries) {
      if (e.value <= 0) continue;
      await _db.tambahStok(e.key, e.value);
      n++;
    }
    if (n > 0) await refreshProduk();
    return n;
  }

  Future<List<TransaksiItem>> itemsOf(int id) => _db.itemsOf(id);

  Future<void> clearAll() async {
    await _db.clearAll();
    clearCart();
    await refreshProduk();
    await refreshTrx();
  }

  Map<String, dynamic> exportBackupMap() => {
        'version': 2,
        'type': 'full',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'settings': settingsMap(),
        'produks': produk.map((e) => e.toMap()).toList(),
        'transaksis': transaksi.map((e) => e.toMap()).toList(),
        'transaksiItems': allItems.map((e) => e.toMap()).toList(),
      };

  Map<String, dynamic> exportProdukMap() => {
        'version': 2,
        'type': 'produk',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'produks': produk.map((e) => e.toMap()).toList(),
      };

  String exportProdukCsv() {
    final b = StringBuffer(
        'ID,Nama,Barcode,Harga Modal,Harga Jual,Stok,Satuan,Foto\n');
    for (final p in produk) {
      final nama = p.nama.replaceAll('"', '""');
      b.writeln(
          '${p.id},"$nama",${p.barcode ?? ''},${p.hargaModal},${p.harga},${p.stok},${p.satuan},${p.foto ?? ''}');
    }
    return b.toString();
  }

  String exportAllCsv() {
    final b = StringBuffer();
    b.writeln('=== PENGATURAN TOKO ===');
    b.writeln('Nama Toko,Alamat,Telepon,Pemilik');
    b.writeln('"$storeName","$storeAddress","$storePhone","$ownerName"');
    b.writeln();
    b.writeln('=== PRODUK ===');
    b.writeln('ID,Nama,Barcode,Harga Modal,Harga Jual,Stok,Satuan,Foto');
    for (final p in produk) {
      final nama = p.nama.replaceAll('"', '""');
      b.writeln(
          '${p.id},"$nama",${p.barcode ?? ''},${p.hargaModal},${p.harga},${p.stok},${p.satuan},${p.foto ?? ''}');
    }
    b.writeln();
    b.writeln('=== TRANSAKSI ===');
    b.writeln('ID,Tanggal,Total Belanja,Total Bayar,Kembalian,Metode,Status');
    for (final t in transaksi) {
      final tgl =
          DateTime.fromMillisecondsSinceEpoch(t.tanggal).toIso8601String();
      b.writeln(
          '${t.id},$tgl,${t.totalBelanja},${t.totalBayar},${t.kembalian},${t.metode},${t.status},"${t.namaHutang}"');
    }
    b.writeln();
    b.writeln('=== DETAIL TRANSAKSI ===');
    b.writeln(
        'ID,Transaksi ID,Produk ID,Nama Produk,Harga Modal,Harga Satuan,Jumlah,Subtotal');
    for (final i in allItems) {
      final nama = i.namaProduk.replaceAll('"', '""');
      b.writeln(
          '${i.id},${i.transaksiId},${i.produkId},"$nama",${i.hargaModal},${i.hargaSatuan},${i.jumlah},${i.subtotal}');
    }
    return b.toString();
  }

  Future<Map<String, int>> restoreFromJson(Map<String, dynamic> data) async {
    if (data['settings'] != null) {
      await restoreSettings(Map<String, dynamic>.from(data['settings'] as Map));
    }

    final keys = _BackupIdKeys();
    final produkRows = backupRows(data, const ['produks', 'produk'])
        .map((e) => keys.normalize(backupRow(e), const ['id']))
        .toList();
    final itemRows = backupRows(data, const ['transaksiItems'])
        .map((e) =>
            keys.normalize(backupRow(e), const ['id', 'transaksiId', 'produkId']))
        .toList();
    final trxRows = backupRows(data, const ['transaksis', 'transaksi'])
        .map((e) => keys.normalize(backupRow(e), const ['id']))
        .toList();

    // Path foto backup online menunjuk ke storage server, bukan ke mesin ini.
    // Kosongkan yang tidak ada di disk supaya daftarnya tidak menampilkan
    // gambar rusak.
    for (final m in produkRows) {
      final f = m['foto'];
      if (f is String && f.isNotEmpty && !File(f).existsSync()) m['foto'] = null;
    }

    final incomingProduks = produkRows.map(Produk.fromMap).toList();
    // Nama saja tidak cukup: ada produk berbeda dengan nama sama. Cocokkan
    // juga barcode, harga, dan stok supaya tidak ada produk yang hilang.
    String produkKey(Produk p) =>
        '${p.nama.toLowerCase().trim()}|${p.barcode ?? ''}|'
        '${p.harga}|${p.stok}';
    final existingByKey = <String, int>{};
    for (final p in produk) {
      if (p.id != null) existingByKey[produkKey(p)] = p.id!;
    }
    final seenKeys = <String>{};
    final existingProdukIds = <int, int>{};
    final produksToAdd = <Produk>[];
    for (final p in incomingProduks) {
      final key = produkKey(p);
      if (!seenKeys.add(key)) continue;
      final existingId = existingByKey[key];
      if (existingId != null) {
        if (p.id != null) existingProdukIds[p.id!] = existingId;
        continue;
      }
      produksToAdd.add(p);
    }

    // Kelompokkan item sekali saja. Cara lama memindai semua item untuk
    // setiap transaksi, yang sangat lambat untuk backup besar.
    final itemsByTrx = <int, List<TransaksiItem>>{};
    for (final e in itemRows) {
      final it = TransaksiItem.fromMap(e);
      itemsByTrx.putIfAbsent(it.transaksiId, () => []).add(it);
    }

    final incomingTrx = trxRows.map(Transaksi.fromMap).toList();
    // Cocokkan lewat isi transaksi, bukan ID. ID dari file hasil konversi
    // mulai dari 1 sehingga bisa bentrok dengan ID database lokal.
    String trxKey(Transaksi t) =>
        '${t.tanggal}|${t.noUrut}|'
        '${t.totalBelanja}|${t.totalBayar}';
    final existingTrxKeys = transaksi.map(trxKey).toSet();
    final trxToAdd = <Transaksi>[];
    for (final t in incomingTrx) {
      if (!existingTrxKeys.add(trxKey(t))) continue;
      trxToAdd.add(t);
    }

    final result = await _db.restoreFromBackup(
      produks: produksToAdd,
      transaksis: trxToAdd,
      itemsByTrx: itemsByTrx,
      existingProdukIds: existingProdukIds,
    );

    clearCart();
    await refreshProduk();
    await refreshTrx();
    return result;
  }

  Future<int> restoreProdukOnly(List<dynamic> list) async {
    int added = 0;
    final existingNames = produk.map((p) => p.nama.toLowerCase().trim()).toSet();
    for (final e in list) {
      final p = Produk.fromMap(Map<String, dynamic>.from(e as Map));
      if (existingNames.contains(p.nama.toLowerCase().trim())) continue;
      await _db.insertProduk(p.copyWith(id: null));
      added++;
    }
    await refreshProduk();
    return added;
  }
}

/// Baris backup bisa memakai nama key versi offline ('produks') atau versi
/// online ('produk'); yang pertama ditemukan dipakai.
List<dynamic> backupRows(Map<String, dynamic> data, List<String> names) {
  for (final n in names) {
    final v = data[n];
    if (v is List) return v;
  }
  return const [];
}

Map<String, dynamic> backupRow(dynamic e) => Map<String, dynamic>.from(e as Map);

/// ID di backup versi online berupa UUID (Supabase), sedangkan model offline
/// menyimpan ID sebagai int. Setiap ID string dapat angka urut yang sama
/// sepanjang satu restore, jadi relasi produk-transaksi-item tetap cocok.
class _BackupIdKeys {
  final _ids = <String, int>{};

  Map<String, dynamic> normalize(
      Map<String, dynamic> row, List<String> fields) {
    for (final f in fields) {
      final raw = row[f]?.toString().trim();
      row[f] =
          (raw == null || raw.isEmpty) ? null : _ids.putIfAbsent(raw, () => _ids.length + 1);
    }
    return row;
  }
}
