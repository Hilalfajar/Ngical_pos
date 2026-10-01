import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../providers/app.dart';
import '../services/printer_service.dart';
import '../theme.dart';
import '../utils/toast.dart';

class PrinterPage extends StatefulWidget {
  const PrinterPage({super.key});
  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  // Pengaturan printer tersimpan di SharedPreferences via App
  String _selectedType = 'bluetooth'; // bluetooth | wifi | usb | windows
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '9100');
  bool _autoPrint = false;
  bool _printLogo = true;
  bool _printFooter = true;
  String _paperWidth = '58'; // 58mm atau 80mm

  // Bluetooth device yang dipilih
  String _btMac = '';
  String _btName = '';
  List<PairedPrinter> _pairedDevices = [];
  bool _scanning = false;
  bool _testing = false;
  String? _connectingMac; // mac yang lagi diproses konek, null kalau tidak ada

  // Windows / sistem printer
  String _winName = '';
  String _winUrl = '';
  List<Printer> _systemPrinters = [];
  bool _loadingSystem = false;

  @override
  void initState() {
    super.initState();
    final a = context.read<App>();
    _ipCtrl.text = a.printerIp;
    _portCtrl.text = a.printerPort.isNotEmpty ? a.printerPort : '9100';
    // Default di Windows: printer sistem
    final defaultType =
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            ? 'windows'
            : 'bluetooth';
    _selectedType =
        a.printerType.isNotEmpty ? a.printerType : defaultType;
    _autoPrint = a.printerAutoPrint;
    _paperWidth = a.printerPaperWidth.isNotEmpty ? a.printerPaperWidth : '58';
    _btMac = a.printerBluetoothMac;
    _btName = a.printerBluetoothName;
    _winName = a.printerWindowsName;
    _winUrl = a.printerWindowsUrl;
    if (_selectedType == 'bluetooth') {
      _scanBluetooth(silent: true);
    } else if (_selectedType == 'windows') {
      _loadSystemPrinters(silent: true);
    }
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanBluetooth({bool silent = false}) async {
    setState(() => _scanning = true);
    try {
      final devices = await PrinterService.i.getPairedBluetoothDevices();
      if (!mounted) return;
      setState(() => _pairedDevices = devices);
      if (devices.isEmpty && !silent) {
        AppToast.info(context,
            'Tidak ada printer ter-pairing. Pairing dulu lewat Pengaturan Bluetooth HP.',
            title: 'Kosong');
      }
    } catch (e) {
      if (mounted && !silent) {
        AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Konek ke satu printer lalu langsung simpan permanen sebagai
  /// printer default. Bisa dipanggil lagi kapan saja untuk pindah
  /// ke printer Bluetooth lain, settingan lama otomatis tertimpa.
  Future<void> _connectToDevice(PairedPrinter d) async {
    setState(() => _connectingMac = d.macAddress);
    try {
      // Cek apakah lokasi aktif, banyak HP Android butuh ini buat konek BT
      final locStatus = await Permission.locationWhenInUse.serviceStatus;
      if (locStatus.isDisabled && Platform.isAndroid) {
        AppToast.warning(context,
            'Layanan Lokasi (GPS) mati. Aktifkan GPS agar aplikasi bisa terhubung ke printer.',
            title: 'GPS Mati');
        // Tetap lanjut coba konek, siapa tahu HP-nya gak rewel
      }

      final ok = await PrinterService.i.connectBluetooth(d.macAddress);
      if (!mounted) return;
      if (!ok) {
        AppToast.error(context,
            'Gagal konek ke ${d.name.isEmpty ? d.macAddress : d.name}. \n\nTips: \n1. Pastikan printer tidak sedang dipakai aplikasi lain (Tutup Mitra Shopee). \n2. Pastikan GPS/Lokasi menyala. \n3. Matikan & nyalakan lagi Bluetooth.',
            title: 'Gagal Koneksi');
        return;
      }
      setState(() {
        _btMac = d.macAddress;
        _btName = d.name;
        _selectedType = 'bluetooth';
      });
      await _save();
      if (!mounted) return;
      AppToast.success(context,
          '${d.name.isEmpty ? d.macAddress : d.name} tersimpan sebagai printer default',
          title: 'Terhubung');
    } finally {
      if (mounted) setState(() => _connectingMac = null);
    }
  }

  Future<void> _loadSystemPrinters({bool silent = false}) async {
    setState(() => _loadingSystem = true);
    try {
      final list = await PrinterService.i.listSystemPrinters();
      if (!mounted) return;
      setState(() => _systemPrinters = list);
      if (list.isEmpty && !silent) {
        AppToast.info(context,
            'Tidak ada printer sistem yang terdeteksi. Pastikan driver printer sudah terpasang di Windows.',
            title: 'Kosong');
      }
    } catch (e) {
      if (mounted && !silent) {
        AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loadingSystem = false);
    }
  }

  Future<void> _selectSystemPrinter(Printer p) async {
    setState(() {
      _winName = p.name;
      _winUrl = p.url;
      _selectedType = 'windows';
    });
    await _save();
    if (!mounted) return;
    AppToast.success(context,
        '${p.name} tersimpan sebagai printer default. Cetak dari kasir tidak akan membuka dialog lagi.',
        title: 'Printer dipilih');
  }

  Future<void> _save() async {
    await context.read<App>().savePrinterSettings(
      type: _selectedType,
      ip: _ipCtrl.text.trim(),
      port: _portCtrl.text.trim(),
      autoPrint: _autoPrint,
      paperWidth: _paperWidth,
      printLogo: _printLogo,
      printFooter: _printFooter,
      bluetoothMac: _btMac,
      bluetoothName: _btName,
      windowsName: _winName,
      windowsUrl: _winUrl,
    );
    if (mounted) {
      AppToast.success(context, 'Pengaturan printer berhasil disimpan',
          title: 'Tersimpan');
    }
  }

  Future<void> _testPrint() async {
    if (_selectedType == 'usb') {
      AppToast.error(context, 'Tipe USB belum didukung di versi ini');
      return;
    }
    if (_selectedType == 'bluetooth' && _btMac.isEmpty) {
      AppToast.error(context, 'Pilih printer Bluetooth dulu');
      return;
    }
    // windows: langsung dialog print sistem
    setState(() => _testing = true);
    await _save(); // simpan dulu supaya App.cetakStruk pakai setting terbaru
    try {
      final result = await context.read<App>().cetakStruk(
        items: const [
          ReceiptLine(nama: 'Produk Contoh A', qty: 1, harga: 10000, subtotal: 10000),
          ReceiptLine(nama: 'Produk Contoh B', qty: 2, harga: 5000, subtotal: 10000),
        ],
        total: 20000,
        bayar: 20000,
        kembalian: 0,
        metode: 'cash',
      );
      if (!mounted) return;
      if (result.success) {
        AppToast.success(context, result.message, title: 'Cetak Percobaan');
      } else {
        AppToast.error(context, result.message);
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            // Header
            const PageHeader(
              title: 'Printer',
              subtitle: 'Pengaturan printer struk',
            ),
            const SizedBox(height: 20),

            // Tipe printer
            _sectionLabel('TIPE KONEKSI'),
            _card(children: [
              if (Platform.isWindows ||
                  Platform.isLinux ||
                  Platform.isMacOS) ...[
                _typeOption(
                  icon: Icons.print_rounded,
                  label: 'Printer Windows / Sistem',
                  desc:
                      'Pilih driver printer sistem (thermal, A4, PDF). Setelah dipilih, cetak tanpa dialog',
                  value: 'windows',
                ),
                const Divider(height: 1),
              ],
              _typeOption(
                icon: Icons.bluetooth_rounded,
                label: 'Bluetooth',
                desc: 'Printer thermal Bluetooth (paling umum di HP)',
                value: 'bluetooth',
              ),
              const Divider(height: 1),
              _typeOption(
                icon: Icons.wifi_rounded,
                label: 'WiFi / LAN',
                desc: 'Printer thermal jaringan via IP address',
                value: 'wifi',
              ),
              const Divider(height: 1),
              _typeOption(
                icon: Icons.usb_rounded,
                label: 'USB (raw thermal)',
                desc: 'Belum didukung di versi ini',
                value: 'usb',
              ),
            ]),
            const SizedBox(height: 16),

            // Printer sistem (Windows / macOS / Linux) - list driver seperti Bluetooth
            if (_selectedType == 'windows') ...[
              _sectionLabel('PRINTER SISTEM'),
              _card(children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _winName.isEmpty
                            ? 'Belum ada printer tersimpan'
                            : _winName,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _winName.isEmpty ? C.muted : C.text),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loadingSystem ? null : () => _loadSystemPrinters(),
                      icon: _loadingSystem
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(_loadingSystem ? 'Memuat...' : 'Muat Ulang'),
                    ),
                  ]),
                ),
                if (_winName.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: Text(
                      'Printer sudah dipilih. Cetak dari kasir akan langsung ke printer ini tanpa dialog.',
                      style: TextStyle(fontSize: 12, color: C.muted, height: 1.35),
                    ),
                  ),
                ],
                if (_systemPrinters.isNotEmpty) ...[
                  const Divider(height: 1),
                  ..._systemPrinters.map((p) {
                    final selected = (_winUrl.isNotEmpty && p.url == _winUrl) ||
                        (_winName.isNotEmpty && p.name == _winName);
                    return InkWell(
                      onTap: () => _selectSystemPrinter(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Icon(Icons.print_rounded,
                              size: 18,
                              color: selected ? C.brand : C.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  if (p.model != null && p.model!.isNotEmpty)
                                    Text(p.model!,
                                        style: const TextStyle(
                                            fontSize: 11, color: C.muted)),
                                ]),
                          ),
                          // Titik 3: atur kertas / print setup
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 20),
                            padding: EdgeInsets.zero,
                            onSelected: (value) async {
                              if (value == 'select') {
                                await _selectSystemPrinter(p);
                              } else if (value == 'paper58') {
                                setState(() {
                                  _paperWidth = '58';
                                  _winName = p.name;
                                  _winUrl = p.url;
                                  _selectedType = 'windows';
                                });
                                await _save();
                              } else if (value == 'paper80') {
                                setState(() {
                                  _paperWidth = '80';
                                  _winName = p.name;
                                  _winUrl = p.url;
                                  _selectedType = 'windows';
                                });
                                await _save();
                              } else if (value == 'clear') {
                                setState(() {
                                  _winName = '';
                                  _winUrl = '';
                                });
                                await _save();
                                if (mounted) {
                                  AppToast.info(context,
                                      'Printer sistem di-reset. Cetak akan membuka dialog lagi.',
                                      title: 'Reset');
                                }
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'select',
                                child: Text('Pilih sebagai default'),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'paper58',
                                child: Text(
                                  'Kertas 58mm${_paperWidth == '58' && selected ? ' ✓' : ''}',
                                ),
                              ),
                              PopupMenuItem(
                                value: 'paper80',
                                child: Text(
                                  'Kertas 80mm${_paperWidth == '80' && selected ? ' ✓' : ''}',
                                ),
                              ),
                              if (selected) ...[
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'clear',
                                  child: Text('Hapus pilihan (pakai dialog)'),
                                ),
                              ],
                            ],
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                color: C.brand, size: 18)
                          else
                            const Text('Pilih',
                                style: TextStyle(
                                    color: C.brand,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                        ]),
                      ),
                    );
                  }),
                ] else if (!_loadingSystem) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Tekan "Muat Ulang" untuk menampilkan daftar printer yang terpasang di sistem (EPSON, thermal USB, Microsoft Print to PDF, dll).',
                      style: TextStyle(fontSize: 12, color: C.muted, height: 1.4),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 16),
            ],

            // Bluetooth device picker
            if (_selectedType == 'bluetooth') ...[
              _sectionLabel('PRINTER DEFAULT'),
              _card(children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _btMac.isEmpty
                            ? 'Belum ada printer tersimpan'
                            : (_btName.isEmpty ? _btMac : '$_btName ($_btMac)'),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _btMac.isEmpty ? C.muted : C.text),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _scanning ? null : _scanBluetooth,
                      icon: _scanning
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.bluetooth_searching_rounded, size: 16),
                      label: Text(_scanning ? 'Mencari...' : 'Cari'),
                    ),
                  ]),
                ),
                if (_pairedDevices.isNotEmpty) ...[
                  const Divider(height: 1),
                  ..._pairedDevices.map((d) => InkWell(
                        onTap: _connectingMac != null
                            ? null
                            : () => _connectToDevice(d),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(children: [
                            Icon(Icons.print_rounded,
                                size: 18,
                                color: _btMac == d.macAddress
                                    ? C.brand
                                    : C.muted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(d.name.isEmpty ? '(tanpa nama)' : d.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    Text(d.macAddress,
                                        style: const TextStyle(
                                            fontSize: 11, color: C.muted)),
                                  ]),
                            ),
                            if (_connectingMac == d.macAddress)
                              const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                            else if (_btMac == d.macAddress)
                              const Icon(Icons.check_circle_rounded,
                                  color: C.brand, size: 18)
                            else
                              const Text('Konek',
                                  style: TextStyle(
                                      color: C.brand,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                          ]),
                        ),
                      )),
                ],
              ]),
              const SizedBox(height: 16),
            ],

            // WiFi settings
            if (_selectedType == 'wifi') ...[
              _sectionLabel('ALAMAT PRINTER'),
              _card(children: [
                _field('IP Address', _ipCtrl,
                    hint: '192.168.1.100',
                    icon: Icons.router_outlined,
                    inputType: TextInputType.number),
                const SizedBox(height: 14),
                _field('Port', _portCtrl,
                    hint: '9100',
                    icon: Icons.settings_ethernet_rounded,
                    inputType: TextInputType.number),
              ]),
              const SizedBox(height: 16),
            ],

            // Ukuran kertas
            _sectionLabel('UKURAN KERTAS'),
            _card(children: [
              _paperOption('58mm', '58', 'Kertas 58mm  kecil, hemat'),
              const Divider(height: 1),
              _paperOption('80mm', '80', 'Kertas 80mm  standar kasir'),
            ]),
            const SizedBox(height: 16),

            // Opsi cetak
            _sectionLabel('OPSI STRUK'),
            _card(children: [
              _switchTile(
                icon: Icons.image_outlined,
                label: 'Cetak Logo Toko',
                desc: 'Tampilkan logo di bagian atas struk',
                value: _printLogo,
                onChanged: (v) => setState(() => _printLogo = v),
              ),
              const Divider(height: 1),
              _switchTile(
                icon: Icons.notes_rounded,
                label: 'Cetak Footer',
                desc: 'Pesan penutup di bawah struk',
                value: _printFooter,
                onChanged: (v) => setState(() => _printFooter = v),
              ),
              const Divider(height: 1),
              _switchTile(
                icon: Icons.print_rounded,
                label: 'Auto Print',
                desc: 'Cetak otomatis setelah transaksi selesai',
                value: _autoPrint,
                onChanged: (v) => setState(() => _autoPrint = v),
              ),
            ]),
            const SizedBox(height: 20),

            // Preview struk
            _sectionLabel('PREVIEW STRUK'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.border),
              ),
              child: Column(children: [
                const Text('================================',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                Consumer<App>(builder: (_, a, __) {
                  return Column(children: [
                    Text(a.storeName,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    if (a.storeAddress.isNotEmpty)
                      Text(a.storeAddress,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 11)),
                    if (a.storePhone.isNotEmpty)
                      Text(a.storePhone,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 11)),
                  ]);
                }),
                const Text('================================',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                const Text('No: #001  14:30 25/08/2025',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                const Text('--------------------------------',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                const Text('Produk A          1 x 10.000',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                const Text('Produk B          2 x  5.000',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                const Text('--------------------------------',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                const Text('Total       :    Rp20.000',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                if (_printFooter)
                  const Text('Terima kasih telah berbelanja!',
                      style:
                          TextStyle(fontFamily: 'monospace', fontSize: 11)),
                const Text('================================',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 20),

            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _testPrint,
                  icon: _testing
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.receipt_long_rounded, size: 18),
                  label: Text(_testing ? 'Mencetak...' : 'Cetak Percobaan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Simpan'),
                ),
              ),
            ]),
          ],
        ),
        ), // ContentWidth
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: C.faint,
                letterSpacing: 1.1)),
      );

  Widget _card({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.borderSoft),
          boxShadow: cardShadow,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _typeOption({
    required IconData icon,
    required String label,
    required String desc,
    required String value,
  }) =>
      InkWell(
        onTap: () {
          setState(() => _selectedType = value);
          if (value == 'windows' && _systemPrinters.isEmpty) {
            _loadSystemPrinters(silent: true);
          } else if (value == 'bluetooth' && _pairedDevices.isEmpty) {
            _scanBluetooth(silent: true);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _selectedType == value ? C.brandLight : C.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 18,
                  color: _selectedType == value ? C.brand : C.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _selectedType == value
                                ? C.brand
                                : C.text)),
                    Text(desc,
                        style:
                            const TextStyle(color: C.muted, fontSize: 12)),
                  ]),
            ),
            if (_selectedType == value)
              const Icon(Icons.check_circle_rounded,
                  color: C.brand, size: 20),
          ]),
        ),
      );

  Widget _paperOption(String label, String value, String desc) =>
      InkWell(
        onTap: () => setState(() => _paperWidth = value),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.receipt_long_outlined,
                size: 20, color: C.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _paperWidth == value ? C.brand : C.text)),
                    Text(desc,
                        style: const TextStyle(
                            color: C.muted, fontSize: 12)),
                  ]),
            ),
            if (_paperWidth == value)
              const Icon(Icons.check_circle_rounded,
                  color: C.brand, size: 20),
          ]),
        ),
      );

  Widget _switchTile({
    required IconData icon,
    required String label,
    required String desc,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 20, color: C.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: C.text)),
                  Text(desc,
                      style:
                          const TextStyle(color: C.muted, fontSize: 12)),
                ]),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: C.brand,
          ),
        ]),
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    IconData? icon,
    TextInputType inputType = TextInputType.text,
  }) =>
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: C.muted)),
              const SizedBox(height: 6),
              TextField(
                controller: ctrl,
                keyboardType: inputType,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: icon != null
                      ? Icon(icon, size: 18, color: C.muted)
                      : null,
                ),
              ),
            ]),
      );
}
