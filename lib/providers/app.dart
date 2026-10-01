import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db.dart';
import '../models/models.dart';
import '../services/printer_service.dart';
import '../services/backup_service.dart';

class App extends ChangeNotifier {
  final _db = Db.i;

  List<Produk> produk = [];
  List<Bahan> bahan = [];

  /// resep per produkId
  Map<int, List<ResepItem>> resepMap = {};

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

  /// Fitur HPP/resep bahan - nonaktif default (warung sembako tidak perlu)
  bool hppEnabled = false;

  // ─── Staff mode (opsional) ─────────────────────────────────
  /// Default OFF → app terbuka bebas seperti sekarang
  bool staffModeEnabled = false;
  List<Staff> staffList = [];
  Staff? currentStaff; // null = belum login

  bool get isStaffLoggedIn => currentStaff != null;
  bool get isManagerLoggedIn => currentStaff?.isManager == true;
  bool get hasManager => staffList.any((s) => s.role == 'Manager' && s.aktif);

  /// Mapping tab UI → key permission
  static const Map<String, String> tabPermissionKey = {
    'POS': 'pos',
    'Produk': 'produk',
    'UpdateStok': 'produk',
    'Transaksi': 'laporan',
    'Staff': 'staff',
    'Printer': 'printer',
    'Backup': 'backup',
    'Settings': 'settings',
    'SettingsMenu': 'settings',
    'About': 'settings',
  };

  /// Cek apakah menu boleh dibuka
  bool canAccessMenu(String tabOrKey) {
    // Mode staff OFF → semua bebas
    if (!staffModeEnabled) return true;

    // SettingsMenu: boleh jika ada minimal 1 sub-menu yang diizinkan
    if (tabOrKey == 'SettingsMenu') {
      const subs = ['settings', 'printer', 'staff', 'backup'];
      return subs.any(canAccessMenu);
    }

    final key = tabPermissionKey[tabOrKey] ?? tabOrKey;

    // Belum login → izinkan area pengaturan agar bisa buka Staff
    if (currentStaff == null) {
      return key == 'staff' || key == 'settings' || key == 'printer';
    }

    // Manager → semua
    if (currentStaff!.isManager) return true;

    // Non-manager → sesuai permissions
    return currentStaff!.permissions.contains(key);
  }

  /// Apakah transaksi (kasir/produk/laporan) terkunci karena mode staff?
  bool get isOpsLocked => staffModeEnabled && currentStaff == null;

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
    await refreshStaff();
    await refreshProduk();
    await refreshTiers();
    await refreshStokUpdate();
    await refreshBahan();
    await refreshResep();
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
    hppEnabled = prefs.getBool('hppEnabled') ?? hppEnabled;
    staffModeEnabled = prefs.getBool('staffModeEnabled') ?? false;
    notifyListeners();
  }

  Future<void> setHppEnabled(bool enabled) async {
    hppEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hppEnabled', enabled);
  }

  // ─── Staff ─────────────────────────────────────────────────

  Future<void> refreshStaff() async {
    staffList = await _db.allStaff();
    // Jika current staff dihapus / nonaktif, logout
    if (currentStaff != null) {
      final still = staffList.where((s) => s.id == currentStaff!.id).toList();
      if (still.isEmpty || !still.first.aktif) {
        currentStaff = null;
      } else {
        currentStaff = still.first;
      }
    }
    notifyListeners();
  }

  /// Nyalakan / matikan mode staff. Hanya Manager (atau belum ada manager sama sekali untuk setup awal).
  Future<String?> setStaffModeEnabled(bool enabled) async {
    if (enabled) {
      if (!hasManager) {
        return 'Buat akun Manager dulu sebelum mengaktifkan Mode Staff.';
      }
      // Harus login sebagai Manager untuk ON
      if (currentStaff == null || !currentStaff!.isManager) {
        return 'Login sebagai Manager untuk mengaktifkan Mode Staff.';
      }
    } else {
      // OFF juga hanya Manager
      if (currentStaff == null || !currentStaff!.isManager) {
        return 'Login sebagai Manager untuk mematikan Mode Staff.';
      }
    }
    staffModeEnabled = enabled;
    if (!enabled) {
      // Saat OFF, sesi login tidak wajib - boleh tetap login atau clear
      // Kita biarkan session, tapi akses sudah bebas.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('staffModeEnabled', enabled);
    notifyListeners();
    return null;
  }

  /// Login dengan PIN. Return error message atau null jika sukses.
  Future<String?> loginStaff(
      {required int staffId, required String pin}) async {
    final match = staffList.where((s) => s.id == staffId).toList();
    if (match.isEmpty) return 'Staff tidak ditemukan.';
    final s = match.first;
    if (!s.aktif) return 'Akun staff nonaktif.';
    if (s.pin != pin) return 'PIN salah.';
    currentStaff = s;
    notifyListeners();
    return null;
  }

  void logoutStaff() {
    currentStaff = null;
    // Kalau mode staff ON, arahkan ke tab Staff biar bisa login lagi
    if (staffModeEnabled && !canAccessMenu(tab)) {
      tab = 'Staff';
    }
    notifyListeners();
  }

  Future<String?> saveStaff(Staff s) async {
    // Aturan:
    // - Belum ada Manager sama sekali → boleh tambah bebas (akun pertama = Manager)
    // - Sudah ada Manager → wajib login sebagai Manager
    if (hasManager && (currentStaff == null || !currentStaff!.isManager)) {
      return 'Login sebagai Manager untuk mengelola user.';
    }

    // Pastikan permissions
    final toSave = s.copyWith(
      permissions: s.isManager
          ? Staff.defaultPermissions('Manager')
          : (s.permissions.isEmpty
              ? Staff.defaultPermissions(s.role)
              : s.permissions),
    );

    if (toSave.id == null) {
      await _db.insertStaff(toSave);
    } else {
      await _db.updateStaff(toSave);
    }
    await refreshStaff();
    return null;
  }

  Future<String?> deleteStaffById(int id) async {
    if (hasManager && (currentStaff == null || !currentStaff!.isManager)) {
      return 'Login sebagai Manager untuk menghapus user.';
    }
    // Jangan hapus manager terakhir kalau mode staff ON
    final target = staffList.where((s) => s.id == id).toList();
    if (target.isNotEmpty &&
        target.first.role == 'Manager' &&
        staffList.where((s) => s.role == 'Manager' && s.aktif).length <= 1 &&
        staffModeEnabled) {
      return 'Tidak bisa hapus Manager terakhir saat Mode Staff aktif.';
    }
    await _db.deleteStaff(id);
    if (currentStaff?.id == id) currentStaff = null;
    await refreshStaff();
    return null;
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

  Future<void> refreshBahan() async {
    bahan = await _db.allBahan();
    notifyListeners();
  }

  Future<void> refreshResep() async {
    final all = await _db.allResep();
    final map = <int, List<ResepItem>>{};
    for (final r in all) {
      map.putIfAbsent(r.produkId, () => []).add(r);
    }
    resepMap = map;
    notifyListeners();
  }

  Future<void> refreshTrx() async {
    transaksi = await _db.allTransaksi();
    allItems = await _db.allItems();
    notifyListeners();
  }

  /// Hitung HPP (harga modal) dari resep produk
  int hitungHpp(int produkId) {
    final items = resepMap[produkId] ?? [];
    if (items.isEmpty) return 0;
    int total = 0;
    for (final r in items) {
      final b = bahan.where((e) => e.id == r.bahanId).firstOrNull;
      if (b == null) continue;
      total += (b.hargaPerSatuan * r.qty).round();
    }
    return total;
  }

  List<ResepItem> resepOf(int produkId) =>
      List.unmodifiable(resepMap[produkId] ?? const []);

  /// null = sukses, string = alasan ditolak (untuk toast di UI)
  String? setTab(String t) {
    if (!canAccessMenu(t)) {
      if (staffModeEnabled && currentStaff == null) {
        // Belum login → ke halaman Staff untuk login
        tab = 'Staff';
        notifyListeners();
        return 'Login staff dulu untuk membuka menu ini';
      }
      // Sudah login tapi tidak punya permission
      notifyListeners();
      return 'Akun ${currentStaff?.role ?? ''} tidak punya akses menu ini';
    }
    tab = t;
    notifyListeners();
    return null;
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
    await refreshBahan(); // stok bahan ikut terpotong
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
    await refreshBahan();
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

  Future<void> saveProduk(Produk p,
      {List<ResepItem>? resep, List<HargaTier>? tiers}) async {
    int id;
    // Jika pakai HPP, modal dihitung otomatis
    var toSave = p;
    if (p.gunakanHpp && p.id != null) {
      final hpp = hitungHpp(p.id!);
      toSave = p.copyWith(hargaModal: hpp);
    }
    if (toSave.id == null) {
      id = await _db.insertProduk(toSave);
    } else {
      id = toSave.id!;
      await _db.updateProduk(toSave);
    }
    if (resep != null) {
      await _db.setResep(
        id,
        resep
            .map((r) => ResepItem(
                  id: r.id,
                  produkId: id,
                  bahanId: r.bahanId,
                  qty: r.qty,
                ))
            .toList(),
      );
      await refreshResep();
      // Setelah resep tersimpan, sync ulang harga modal dari HPP
      if (toSave.gunakanHpp) {
        final hpp = hitungHpp(id);
        final updated =
            (await _db.allProduk()).where((e) => e.id == id).firstOrNull;
        if (updated != null) {
          await _db.updateProduk(updated.copyWith(hargaModal: hpp));
        }
      }
    } else if (!toSave.gunakanHpp && toSave.id != null) {
      // Mode manual: hapus resep lama biar tidak membingungkan
      // (opsional - biarkan resep tetap ada kalau user tinggal matikan switch)
    }
    if (tiers != null) {
      await _db.setTiers(id, tiers);
      await refreshTiers();
    }
    await refreshProduk();
  }

  Future<void> deleteProduk(int id) async {
    await _db.deleteResepOf(id);
    await _db.deleteTiersOf(id);
    await _db.deleteProduk(id);
    await refreshResep();
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

  Future<void> saveBahan(Bahan b) async {
    if (b.id == null) {
      await _db.insertBahan(b);
    } else {
      await _db.updateBahan(b);
    }
    await refreshBahan();
    // Update harga modal semua produk HPP yang memakai bahan ini
    await _syncHppAll();
  }

  /// Restok bahan: tambah stok + update harga acuan (tanpa ubah resep)
  /// [qty] jumlah yang baru dibeli, [hargaTotal] total bayar untuk qty itu.
  Future<void> restokBahan(Bahan b, double qty, int hargaTotal) async {
    if (b.id == null || qty <= 0) return;
    final newStok = b.stok + qty;
    // Harga acuan pakai pembelian terakhir (sederhana & jelas untuk user)
    final updated = b.copyWith(
      stok: newStok,
      jumlahBeli: qty,
      hargaBeli: hargaTotal,
    );
    await _db.updateBahan(updated);
    await refreshBahan();
    await _syncHppAll();
  }

  Future<void> deleteBahan(int id) async {
    await _db.deleteBahan(id);
    await refreshBahan();
    await refreshResep();
    await _syncHppAll();
  }

  /// Hitung ulang harga modal semua produk yang gunakanHpp
  Future<void> _syncHppAll() async {
    await refreshResep();
    var changed = false;
    for (final p in List<Produk>.from(produk)) {
      if (!p.gunakanHpp || p.id == null) continue;
      final hpp = hitungHpp(p.id!);
      if (hpp != p.hargaModal) {
        await _db.updateProduk(p.copyWith(hargaModal: hpp));
        changed = true;
      }
    }
    if (changed) await refreshProduk();
  }

  Future<List<TransaksiItem>> itemsOf(int id) => _db.itemsOf(id);

  Future<void> clearAll() async {
    await _db.clearAll();
    clearCart();
    await refreshProduk();
    await refreshBahan();
    await refreshResep();
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
    int addedProduk = 0, addedTrx = 0, addedItems = 0;

    if (data['settings'] != null) {
      await restoreSettings(Map<String, dynamic>.from(data['settings'] as Map));
    }

    final incomingProduks = (data['produks'] as List? ?? [])
        .map((e) => Produk.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final existingIds = produk.map((p) => p.id).toSet();
    for (final p in incomingProduks) {
      if (p.id != null && existingIds.contains(p.id)) continue;
      await _db.insertProduk(p.copyWith(id: null));
      addedProduk++;
    }

    if (data.containsKey('transaksis')) {
      final incomingTrx = (data['transaksis'] as List? ?? [])
          .map((e) => Transaksi.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      final existingTrxIds = transaksi.map((t) => t.id).toSet();
      for (final t in incomingTrx) {
        if (t.id != null && existingTrxIds.contains(t.id)) continue;
        final newId = await _db.insertTransaksi(Transaksi(
          tanggal: t.tanggal,
          totalBelanja: t.totalBelanja,
          totalBayar: t.totalBayar,
          kembalian: t.kembalian,
          metode: t.metode,
          status: t.status,
          namaHutang: t.namaHutang,
        ));
        addedTrx++;
        final itemsForTrx = (data['transaksiItems'] as List? ?? [])
            .map((e) =>
                TransaksiItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .where((i) => i.transaksiId == t.id)
            .map((i) => TransaksiItem(
                  transaksiId: newId,
                  produkId: i.produkId,
                  namaProduk: i.namaProduk,
                  hargaModal: i.hargaModal,
                  hargaSatuan: i.hargaSatuan,
                  jumlah: i.jumlah,
                  subtotal: i.subtotal,
                ))
            .toList();
        if (itemsForTrx.isNotEmpty) {
          await _db.insertItems(itemsForTrx);
          addedItems += itemsForTrx.length;
        }
      }
    }

    clearCart();
    await refreshProduk();
    await refreshTrx();
    return {'produk': addedProduk, 'transaksi': addedTrx, 'items': addedItems};
  }

  Future<int> restoreProdukOnly(List<dynamic> list) async {
    int added = 0;
    final existingIds = produk.map((p) => p.id).toSet();
    for (final e in list) {
      final p = Produk.fromMap(Map<String, dynamic>.from(e as Map));
      if (p.id != null && existingIds.contains(p.id)) continue;
      await _db.insertProduk(p.copyWith(id: null));
      added++;
    }
    await refreshProduk();
    return added;
  }
}
