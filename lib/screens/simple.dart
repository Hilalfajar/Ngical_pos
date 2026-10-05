import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app.dart';
import '../theme.dart';
import '../utils/toast.dart';
import 'printer.dart';
import 'staff.dart';

//  About

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              const PageHeader(
                title: 'Tentang',
                subtitle: 'Informasi aplikasi',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: cardShadow,
                  border: Border.all(color: C.borderSoft),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: C.brand,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.point_of_sale_rounded,
                          size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Ngical',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: C.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: C.brandLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Versi 1.1.28',
                        style: TextStyle(
                          color: C.brand,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Aplikasi kasir sederhana untuk warung dan toko kecil. '
                      'Kelola produk, transaksi, dan laporan penjualan dengan mudah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: C.text2,
                        height: 1.55,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: C.borderSoft),
                ),
                child: Column(
                  children: [
                    _AboutRow(
                      icon: Icons.inventory_2_rounded,
                      label: 'Kelola Produk',
                      desc: 'Tambah, edit, dan pantau stok',
                    ),
                    const Divider(height: 24),
                    _AboutRow(
                      icon: Icons.point_of_sale_rounded,
                      label: 'Kasir Cepat',
                      desc: 'Proses transaksi dalam hitungan detik',
                    ),
                    const Divider(height: 24),
                    _AboutRow(
                      icon: Icons.bar_chart_rounded,
                      label: 'Laporan',
                      desc: 'Pantau pendapatan & keuntungan',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ), // ContentWidth
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  const _AboutRow(
      {required this.icon, required this.label, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: C.brandLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: C.brand, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: C.text)),
              Text(desc, style: const TextStyle(color: C.muted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

//  Settings

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _name, _addr, _phone, _owner;
  late final TextEditingController _qris, _bank, _rek, _atNama;
  int _tab = 0; // 0=Toko, 1=Pembayaran

  @override
  void initState() {
    super.initState();
    final a = context.read<App>();
    _name = TextEditingController(text: a.storeName);
    _addr = TextEditingController(text: a.storeAddress);
    _phone = TextEditingController(text: a.storePhone);
    _owner = TextEditingController(text: a.ownerName);
    _qris = TextEditingController(text: a.qrisToken);
    _bank = TextEditingController(text: a.bankName);
    _rek = TextEditingController(text: a.noRekening);
    _atNama = TextEditingController(text: a.atasNama);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _addr,
      _phone,
      _owner,
      _qris,
      _bank,
      _rek,
      _atNama
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (files.isNotEmpty && files.first.path != null) {
      await context.read<App>().saveSettings(logo: files.first.path!);
      setState(() {});
    }
  }

  Future<void> _save() async {
    await context.read<App>().saveSettings(
          name: _name.text.trim(),
          address: _addr.text.trim(),
          phone: _phone.text.trim(),
          owner: _owner.text.trim(),
          qris: _qris.text.trim(),
          bank: _bank.text.trim(),
          rek: _rek.text.trim(),
          atNama: _atNama.text.trim(),
        );
    if (mounted) {
      AppToast.success(context, 'Pengaturan toko berhasil disimpan',
          title: 'Tersimpan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: ContentWidth(
          child: Column(children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: PageHeader(
                title: 'Pengaturan',
                subtitle: 'Informasi toko & pembayaran',
              ),
            ),
            // Tab selector
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  _TabBtn(
                      label: 'Info Toko',
                      active: _tab == 0,
                      onTap: () => setState(() => _tab = 0)),
                  _TabBtn(
                      label: 'Pembayaran',
                      active: _tab == 1,
                      onTap: () => setState(() => _tab = 1)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                children: [
                  if (_tab == 0) ..._buildTokoTab(a),
                  if (_tab == 1) ..._buildPembayaranTab(a),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Simpan Perubahan'),
                  ),
                ],
              ),
            ),
          ]),
        ), // ContentWidth
      ),
    );
  }

  List<Widget> _buildTokoTab(App a) => [
        // Logo toko
        Center(
          child: GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: C.brandLight,
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: C.brand.withValues(alpha: 0.3), width: 2),
              ),
              clipBehavior: Clip.hardEdge,
              child: a.storeLogo.isNotEmpty && File(a.storeLogo).existsSync()
                  ? Image.file(File(a.storeLogo), fit: BoxFit.cover)
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Icon(Icons.add_a_photo_outlined,
                              color: C.brand, size: 28),
                          SizedBox(height: 4),
                          Text('Logo',
                              style: TextStyle(
                                  color: C.brand,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _card(children: [
          _fl('Nama Toko', _name,
              hint: 'Warung Maju', icon: Icons.storefront_rounded),
          const SizedBox(height: 14),
          _fl('Alamat', _addr,
              hint: 'Alamat lengkap', icon: Icons.location_on_outlined),
          const SizedBox(height: 14),
          _fl('No. Telepon', _phone,
              hint: '08xx',
              icon: Icons.phone_outlined,
              inputType: TextInputType.phone),
          const SizedBox(height: 14),
          _fl('Nama Pemilik', _owner,
              hint: 'Nama Anda', icon: Icons.person_outline),
        ]),
      ];

  List<Widget> _buildPembayaranTab(App a) => [
        // QRIS
        _sectionHeader(Icons.qr_code_rounded, 'QRIS', C.brand),
        const SizedBox(height: 8),
        _card(children: [
          _fl('Token QRIS', _qris,
              hint: '00020101021126610016...',
              icon: Icons.qr_code_scanner,
              maxLines: 4),
          if (a.qrisToken.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: C.brandLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 14, color: C.brand),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                      'Token disimpan. Akan ditampilkan saat checkout QRIS.',
                      style: TextStyle(fontSize: 11, color: C.brand)),
                ),
              ]),
            ),
          ],
        ]),
        const SizedBox(height: 16),
        // Transfer
        _sectionHeader(Icons.account_balance_outlined, 'Transfer Bank', C.text),
        const SizedBox(height: 8),
        _card(children: [
          _fl('Nama Bank', _bank,
              hint: 'BCA, BRI, Mandiri...',
              icon: Icons.account_balance_outlined),
          const SizedBox(height: 14),
          _fl('No. Rekening', _rek,
              hint: '1234567890',
              icon: Icons.credit_card_outlined,
              inputType: TextInputType.number),
          const SizedBox(height: 14),
          _fl('Atas Nama', _atNama,
              hint: 'Nama pemilik rekening', icon: Icons.person_outline),
        ]),
      ];

  Widget _sectionHeader(IconData icon, String label, Color color) =>
      Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: color)),
      ]);

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: C.borderSoft),
          boxShadow: cardShadow,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _fl(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    IconData? icon,
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: inputType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon:
                icon != null ? Icon(icon, size: 18, color: C.muted) : null,
          ),
        ),
      ]);
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active ? cardShadow : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? C.brand : C.muted,
            ),
          ),
        ),
      ),
    );
  }
}

//  Backup & Restore

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _loading = false;
  String _status = '';

  String get _ts => DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

  /// Dapatkan folder Downloads yang bisa diakses user
  Future<String> get _saveDir async {
    if (Platform.isAndroid) {
      // Android: simpan ke Downloads (/sdcard/Download)
      return '/storage/emulated/0/Download';
    }
    // iOS / Desktop: Documents
    final d = await getApplicationDocumentsDirectory();
    return d.path;
  }

  /// Minta izin storage Android (hanya untuk Android < 13)
  Future<bool> _ensurePermission() async {
    if (!Platform.isAndroid) return true;
    // Android 13+ (SDK 33) tidak perlu permission WRITE_EXTERNAL_STORAGE
    // File picker handle ini sendiri
    return true;
  }

  Future<String> _saveFile(String name, String content) async {
    await _ensurePermission();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final saveUri = await FilePicker.saveFile(
        dialogTitle: 'Simpan Backup',
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
      if (saveUri != null) {
        final savePath = saveUri.toFilePath();
        await File(savePath).writeAsString(content);
        return savePath;
      }
    }
    // Mobile: langsung simpan ke Downloads
    final dir = await _saveDir;
    await Directory(dir).create(recursive: true);
    final f = File('$dir/$name');
    await f.writeAsString(content, flush: true);
    return f.path;
  }

  Future<String> _saveBytes(String name, List<int> bytes) async {
    await _ensurePermission();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final saveUri = await FilePicker.saveFile(
        dialogTitle: 'Simpan Backup',
        fileName: name,
        bytes: Uint8List.fromList(bytes),
      );
      if (saveUri != null) {
        final savePath = saveUri.toFilePath();
        await File(savePath).writeAsBytes(bytes);
        return savePath;
      }
    }
    final dir = await _saveDir;
    await Directory(dir).create(recursive: true);
    final f = File('$dir/$name');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppToast.error(context, msg);
    } else {
      AppToast.success(context, msg);
    }
  }

  void _setStatus(String s) {
    if (mounted) {
      setState(() {
        _status = s;
        _loading = s.isNotEmpty;
      });
    }
  }

  Future<void> _backupAll() async {
    final format = await _pickFormatDialog(
      title: 'Format Backup Semua Data',
      options: const [
        ('json', 'ZIP + JSON (direkomendasikan)'),
        ('csv', 'CSV (Excel Compatible)'),
        ('sql', 'SQL Dump'),
      ],
    );
    if (format == null || !mounted) return;

    _setStatus('Menyiapkan backup...');
    try {
      final a = context.read<App>();
      String savedPath;

      if (format == 'json') {
        _setStatus('Membuat arsip ZIP...');
        final archive = Archive();

        final jsonStr =
            const JsonEncoder.withIndent('  ').convert(a.exportBackupMap());
        final jsonBytes = utf8.encode(jsonStr);
        archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

        int fotoCount = 0;
        for (final p in a.produk) {
          if (p.foto != null && File(p.foto!).existsSync()) {
            final fotoBytes = await File(p.foto!).readAsBytes();
            final fotoName =
                'foto/${p.id}_${p.foto!.split('/').last.split('\\').last}';
            archive.addFile(ArchiveFile(fotoName, fotoBytes.length, fotoBytes));
            fotoCount++;
          }
        }

        final zipBytes = ZipEncoder().encode(archive)!;
        savedPath = await _saveBytes('Ngical_Backup_$_ts.zip', zipBytes);
        _toast(
            'Backup disimpan ke:\n$savedPath\n(${a.produk.length} produk, ${a.transaksi.length} transaksi, $fotoCount foto)');
      } else if (format == 'csv') {
        final csv = a.exportAllCsv();
        savedPath = await _saveFile('Ngical_Backup_$_ts.csv', csv);
        _toast('Backup CSV disimpan ke:\n$savedPath');
      } else {
        final sql = _buildSqlDump(a);
        savedPath = await _saveFile('Ngical_Backup_$_ts.sql', sql);
        _toast('Backup SQL disimpan ke:\n$savedPath');
      }
    } catch (e) {
      _toast('Gagal backup: $e', isError: true);
    } finally {
      _setStatus('');
    }
  }

  Future<void> _backupProduk() async {
    final format = await _pickFormatDialog(
      title: 'Format Backup Produk',
      options: const [
        ('zip', 'ZIP + Foto (disarankan)'),
        ('json', 'JSON saja (tanpa foto)'),
        ('csv', 'CSV (Excel Compatible)'),
        ('sql', 'SQL'),
      ],
    );
    if (format == null || !mounted) return;

    _setStatus('Menyiapkan backup produk...');
    try {
      final a = context.read<App>();
      String savedPath;

      if (format == 'csv') {
        savedPath = await _saveFile('Produk_$_ts.csv', a.exportProdukCsv());
        _toast('Backup produk disimpan:\n$savedPath');
      } else if (format == 'sql') {
        final b = StringBuffer('-- Backup Produk ${DateTime.now()}\n\n');
        for (final p in a.produk) {
          final nama = p.nama.replaceAll("'", "''");
          final barcode = p.barcode == null ? 'NULL' : "'${p.barcode}'";
          final foto = p.foto == null ? 'NULL' : "'${p.foto}'";
          b.writeln(
            "INSERT OR IGNORE INTO produk(nama,satuan,barcode,hargaModal,harga,stok,foto) "
            "VALUES('$nama','${p.satuan}',$barcode,${p.hargaModal},${p.harga},${p.stok},$foto);",
          );
        }
        savedPath = await _saveFile('Produk_$_ts.sql', b.toString());
        _toast('Backup produk disimpan:\n$savedPath');
      } else if (format == 'json') {
        final json =
            const JsonEncoder.withIndent('  ').convert(a.exportProdukMap());
        savedPath = await _saveFile('Produk_$_ts.json', json);
        _toast('Backup produk disimpan:\n$savedPath');
      } else {
        // ZIP + foto (disarankan)
        final archive = Archive();
        final jsonStr =
            const JsonEncoder.withIndent('  ').convert(a.exportProdukMap());
        final jsonBytes = utf8.encode(jsonStr);
        archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

        int fotoCount = 0;
        for (final p in a.produk) {
          if (p.foto != null && File(p.foto!).existsSync()) {
            final fotoBytes = await File(p.foto!).readAsBytes();
            final base = p.foto!.split('/').last.split('\\').last;
            final fotoName = 'foto/${p.id}_$base';
            archive.addFile(ArchiveFile(fotoName, fotoBytes.length, fotoBytes));
            fotoCount++;
          }
        }

        final zipBytes = ZipEncoder().encode(archive)!;
        savedPath = await _saveBytes('Produk_$_ts.zip', zipBytes);
        _toast(
            'Backup produk disimpan:\n$savedPath\n(${a.produk.length} produk, $fotoCount foto)');
      }
    } catch (e) {
      _toast('Gagal backup produk: $e', isError: true);
    } finally {
      _setStatus('');
    }
  }

  Future<void> _restore() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'zip', 'csv'],
      withData: true,
    );
    if (files.isEmpty || !mounted) return;

    final file = files.first;
    final ext = (file.extension ?? '').toLowerCase();
    Uint8List? bytes;

    if (file.path != null && !kIsWeb) {
      bytes = await File(file.path!).readAsBytes();
    } else {
      _toast('Tidak bisa membaca file', isError: true);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restore data?'),
        content:
            const Text('Data baru dari file akan DITAMBAHKAN ke database.\n'
                'Data yang sudah ada tidak akan dihapus.\n\nLanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    _setStatus('Sedang restore...');
    try {
      final a = context.read<App>();

      if (ext == 'zip') {
        await _restoreZip(a, bytes);
      } else if (ext == 'csv') {
        final text = utf8.decode(bytes);
        final added = await _restoreCsv(a, text);
        _toast('Restore CSV selesai: +$added produk ditambahkan');
      } else {
        // JSON
        final text = utf8.decode(bytes);
        final decoded = jsonDecode(text);
        Map<String, int> result;
        if (decoded is Map && decoded.containsKey('produks')) {
          result = await a.restoreFromJson(Map<String, dynamic>.from(decoded));
        } else if (decoded is List) {
          final added = await a.restoreProdukOnly(decoded);
          result = {'produk': added, 'transaksi': 0, 'items': 0};
        } else {
          throw Exception('Format file tidak dikenali');
        }
        _toast('Restore selesai:\n'
            '+${result['produk']} produk, '
            '+${result['transaksi']} transaksi, '
            '+${result['items']} item');
      }
    } catch (e) {
      _toast('Gagal restore: $e', isError: true);
    } finally {
      _setStatus('');
    }
  }

  /// Restore dari CSV produk (format: ID,Nama,Barcode,Harga Modal,Harga Jual,Stok,Foto)
  /// Restore dari CSV  auto-detect format berdasarkan header baris pertama.
  /// Support 2 format:
  ///   Format 1 (backup app): ID,Nama,Barcode,Harga Modal,Harga Jual,Stok,Foto
  ///   Format 2 (import POS): Kode,Nama,Harga Modal,Harga Jual,Stok,Kategori
  Future<int> _restoreCsv(App a, String csvText) async {
    // Hapus BOM jika ada
    var text = csvText.trimLeft();
    if (text.startsWith('\uFEFF')) text = text.substring(1);

    final lines = text
        .split('\n')
        .map((l) => l.trim().replaceAll('\r', ''))
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return 0;

    // Detect format dari header
    final header = _parseCsvLine(lines[0].toLowerCase());
    final isFormatPOS = header.contains('kode') || header.contains('kategori');

    // Map index kolom
    int iBarcode = -1,
        iNama = -1,
        iModal = -1,
        iHarga = -1,
        iStok = -1,
        iFoto = -1,
        iSatuan = -1;

    if (isFormatPOS) {
      // Format: Kode, Nama, Harga Modal, Harga Jual, Stok, Kategori
      for (int i = 0; i < header.length; i++) {
        final h = header[i].trim();
        if (h == 'kode') {
          iBarcode = i;
        } else if (h == 'nama')
          iNama = i;
        else if (h.contains('modal'))
          iModal = i;
        else if (h.contains('jual') || h == 'harga')
          iHarga = i;
        else if (h == 'stok') iStok = i;
      }
    } else {
      // Format backup app: ID, Nama, Barcode, Harga Modal, Harga Jual, Stok, Foto
      for (int i = 0; i < header.length; i++) {
        final h = header[i].trim();
        if (h == 'id') {/* skip */} else if (h == 'nama')
          iNama = i;
        else if (h == 'barcode')
          iBarcode = i;
        else if (h.contains('modal'))
          iModal = i;
        else if (h.contains('jual') || h == 'harga')
          iHarga = i;
        else if (h == 'stok')
          iStok = i;
        else if (h == 'foto')
          iFoto = i;
        else if (h == 'satuan') iSatuan = i;
      }
    }

    // Fallback jika header tidak dikenali  pakai urutan default
    if (iNama == -1) {
      if (isFormatPOS) {
        iBarcode = 0;
        iNama = 1;
        iModal = 2;
        iHarga = 3;
        iStok = 4;
      } else {
        iNama = 1;
        iBarcode = 2;
        iModal = 3;
        iHarga = 4;
        iStok = 5;
        iSatuan = 6;
        iFoto = 7;
      }
    }

    int added = 0;
    final existingNama =
        a.produk.map((p) => p.nama.toLowerCase().trim()).toSet();
    final existingBarcode = a.produk
        .where((p) => p.barcode != null && p.barcode!.isNotEmpty)
        .map((p) => p.barcode!.toLowerCase().trim())
        .toSet();

    for (int li = 1; li < lines.length; li++) {
      final line = lines[li];
      // Skip section headers
      if (line.startsWith('===') || line.startsWith('=')) continue;
      // Skip jika looks like a header row
      if (line.toLowerCase().startsWith('id,') ||
          line.toLowerCase().startsWith('kode,') ||
          line.toLowerCase().startsWith('nama,')) {
        continue;
      }

      try {
        final cols = _parseCsvLine(line);
        if (cols.length < 2) continue;

        String nama = iNama >= 0 && iNama < cols.length
            ? cols[iNama].replaceAll('"', '').trim()
            : '';
        if (nama.isEmpty) continue;

        String? barcode = iBarcode >= 0 && iBarcode < cols.length
            ? cols[iBarcode].replaceAll('"', '').trim()
            : null;
        if (barcode != null && barcode.isEmpty) barcode = null;

        final modalStr =
            iModal >= 0 && iModal < cols.length ? cols[iModal].trim() : '0';
        final hargaStr =
            iHarga >= 0 && iHarga < cols.length ? cols[iHarga].trim() : '0';
        final stokStr =
            iStok >= 0 && iStok < cols.length ? cols[iStok].trim() : '0';
        final satuanStr = iSatuan >= 0 && iSatuan < cols.length
            ? cols[iSatuan].trim()
            : 'pcs';
        final fotoStr =
            iFoto >= 0 && iFoto < cols.length ? cols[iFoto].trim() : '';

        final modal = _parseNum(modalStr);
        final harga = _parseNum(hargaStr);
        final stok = _parseNum(stokStr);

        if (harga <= 0 && modal <= 0) continue; // baris invalid

        // Cek duplikat
        if (existingNama.contains(nama.toLowerCase())) continue;
        if (barcode != null &&
            existingBarcode.contains(barcode.toLowerCase())) {
          // Barcode sama tapi nama beda  tetap skip untuk hindari duplikat
          continue;
        }

        await a.saveProduk(Produk(
          nama: nama,
          satuan: satuanStr.isEmpty ? 'pcs' : satuanStr.replaceAll('"', ''),
          barcode: barcode,
          hargaModal: modal.toInt(),
          harga: harga > 0
              ? harga.toInt()
              : modal.toInt(), // fallback ke modal jika harga 0
          stok: stok,
          foto: fotoStr.isNotEmpty ? fotoStr : null,
        ));

        existingNama.add(nama.toLowerCase());
        if (barcode != null) existingBarcode.add(barcode.toLowerCase());
        added++;
      } catch (_) {
        continue;
      }
    }
    return added;
  }

  double _parseNum(String s) {
    // Hapus karakter non-numerik kecuali titik
    final clean = s.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    result.add(buf.toString());
    return result;
  }

  Future<void> _restoreZip(App a, Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final dataFile = archive.findFile('data.json');
    if (dataFile == null) throw Exception('data.json tidak ditemukan di ZIP');

    final jsonStr = utf8.decode(dataFile.content as List<int>);
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

    final tmpDir = await getTemporaryDirectory();
    final fotoDir = Directory('${tmpDir.path}/restored_foto');
    await fotoDir.create(recursive: true);

    final fotoMap = <String, String>{};
    for (final f in archive) {
      if (f.name.startsWith('foto/') && f.isFile) {
        final outPath = '${fotoDir.path}/${f.name.split('/').last}';
        await File(outPath).writeAsBytes(f.content as List<int>);
        fotoMap[f.name.split('/').last] = outPath;
      }
    }

    if (decoded['produks'] != null) {
      final produks = decoded['produks'] as List;
      for (final p in produks) {
        if (p['foto'] != null) {
          final fotoFilename =
              (p['foto'] as String).split('/').last.split('\\').last;
          final matched = fotoMap.entries
              .where((e) => e.key.endsWith(fotoFilename))
              .firstOrNull;
          if (matched != null) p['foto'] = matched.value;
        }
      }
    }

    final result = await a.restoreFromJson(decoded);
    _toast(
        'Restore ZIP selesai: +${result['produk']} produk (${fotoMap.length} foto), '
        '+${result['transaksi']} transaksi, +${result['items']} item');
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus semua data?'),
        content: const Text(
            'Produk, transaksi, dan pengaturan akan dihapus permanen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus', style: TextStyle(color: C.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _setStatus('Menghapus data...');
    await context.read<App>().clearAll();
    _setStatus('');
    _toast('Semua data berhasil dihapus');
  }

  Future<String?> _pickFormatDialog({
    required String title,
    required List<(String, String)> options,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        children: options.map((opt) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, opt.$1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: C.brandLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        opt.$1.toUpperCase(),
                        style: const TextStyle(
                          color: C.brand,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(opt.$2,
                        style: const TextStyle(fontSize: 14, color: C.text)),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _buildSqlDump(App a) {
    final b = StringBuffer()
      ..writeln('-- Ngical SQL Backup ${DateTime.now()}')
      ..writeln('-- Settings')
      ..writeln("-- storeName: ${a.storeName}")
      ..writeln("-- storeAddress: ${a.storeAddress}")
      ..writeln("-- storePhone: ${a.storePhone}")
      ..writeln("-- ownerName: ${a.ownerName}")
      ..writeln();

    b.writeln('-- Produk');
    for (final p in a.produk) {
      final nama = p.nama.replaceAll("'", "''");
      final barcode = p.barcode == null ? 'NULL' : "'${p.barcode}'";
      final foto = p.foto == null ? 'NULL' : "'${p.foto}'";
      b.writeln(
        "INSERT OR IGNORE INTO produk(id,nama,satuan,barcode,hargaModal,harga,stok,foto) "
        "VALUES(${p.id},'$nama','${p.satuan}',$barcode,${p.hargaModal},${p.harga},${p.stok},$foto);",
      );
    }
    b.writeln();

    b.writeln('-- Transaksi');
    for (final t in a.transaksi) {
      b.writeln(
        "INSERT OR IGNORE INTO transaksi(id,tanggal,totalBelanja,totalBayar,kembalian) "
        "VALUES(${t.id},${t.tanggal},${t.totalBelanja},${t.totalBayar},${t.kembalian});",
      );
    }
    b.writeln();

    b.writeln('-- Transaksi Item');
    for (final i in a.allItems) {
      final nama = i.namaProduk.replaceAll("'", "''");
      b.writeln(
        "INSERT OR IGNORE INTO transaksi_item(id,transaksiId,produkId,namaProduk,hargaModal,hargaSatuan,jumlah,subtotal) "
        "VALUES(${i.id},${i.transaksiId},${i.produkId},'$nama',${i.hargaModal},${i.hargaSatuan},${i.jumlah},${i.subtotal});",
      );
    }
    return b.toString();
  }

  Future<void> _pickTime(App a) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: a.backupHour, minute: a.backupMinute),
    );
    if (picked == null) return;
    await a.saveBackupSchedule(hour: picked.hour, minute: picked.minute);
  }

  String _fmtLastRun(int millis) {
    if (millis == 0) return 'Belum pernah';
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  static const _hariList = [
    (DateTime.monday, 'Senin'),
    (DateTime.tuesday, 'Selasa'),
    (DateTime.wednesday, 'Rabu'),
    (DateTime.thursday, 'Kamis'),
    (DateTime.friday, 'Jumat'),
    (DateTime.saturday, 'Sabtu'),
    (DateTime.sunday, 'Minggu'),
  ];

  Widget _autoBackupCard(App a) {
    final jam =
        TimeOfDay(hour: a.backupHour, minute: a.backupMinute).format(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.borderSoft),
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Aktifkan backup otomatis',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('Backup terakhir: ${_fmtLastRun(a.backupLastRunAt)}',
                      style: const TextStyle(color: C.muted, fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: a.backupAutoEnabled,
              onChanged: (v) => a.saveBackupSchedule(enabled: v),
            ),
          ]),
          if (a.backupLastError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: C.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Backup terakhir gagal: ${a.backupLastError}',
                  style: const TextStyle(color: C.danger, fontSize: 12)),
            ),
          ],
          if (a.backupAutoEnabled) ...[
            const SizedBox(height: 16),
            const Text('Frekuensi',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _chip(
                  label: 'Harian',
                  selected: a.backupFrequency == 'daily',
                  onTap: () => a.saveBackupSchedule(frequency: 'daily'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _chip(
                  label: 'Mingguan',
                  selected: a.backupFrequency == 'weekly',
                  onTap: () => a.saveBackupSchedule(frequency: 'weekly'),
                ),
              ),
            ]),
            if (a.backupFrequency == 'weekly') ...[
              const SizedBox(height: 12),
              const Text('Hari',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _hariList.map((h) {
                  return _chip(
                    label: h.$2,
                    selected: a.backupWeekday == h.$1,
                    onTap: () => a.saveBackupSchedule(weekday: h.$1),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            const Text('Jam',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickTime(a),
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(jam),
            ),
            const SizedBox(height: 12),
            const Text('Cakupan Data',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _chip(
                  label: 'Semua Data',
                  selected: a.backupScope == 'all',
                  onTap: () => a.saveBackupSchedule(scope: 'all'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _chip(
                  label: 'Hanya Produk',
                  selected: a.backupScope == 'produk',
                  onTap: () => a.saveBackupSchedule(scope: 'produk'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(
              'Backup otomatis dicek tiap kali aplikasi dibuka atau ditutup/diminimize. '
              'Kalau jadwalnya sudah lewat dan belum ke-backup, langsung jalan otomatis saat itu. '
              'File tersimpan di folder Download/NgicalAutoBackup.',
              style: const TextStyle(color: C.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.brand : C.brandLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : C.brand,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String sub,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? C.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _loading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.borderSoft),
              boxShadow: cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: c, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: C.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: const TextStyle(color: C.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: C.faint.withValues(alpha: 0.7), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              const PageHeader(
                title: 'Backup & Restore',
                subtitle: 'Cadangkan dan pulihkan data',
              ),
              const SizedBox(height: 12),

              // Info badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: C.brandLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: C.brand, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${a.produk.length} produk · ${a.transaksi.length} transaksi',
                        style: const TextStyle(
                          color: C.brand,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(_status,
                          style: const TextStyle(color: C.brand, fontSize: 13)),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              const SectionLabel('Backup Otomatis'),
              _autoBackupCard(a),

              const SizedBox(height: 8),
              const SectionLabel('Cadangkan'),
              _actionCard(
                icon: Icons.backup_rounded,
                title: 'Backup Semua Data',
                sub: 'Produk + transaksi + pengaturan + foto',
                onTap: _backupAll,
              ),
              _actionCard(
                icon: Icons.inventory_2_outlined,
                title: 'Backup Produk Saja',
                sub: 'Hanya data produk (JSON / CSV / SQL)',
                onTap: _backupProduk,
              ),

              const SizedBox(height: 8),
              const SectionLabel('Pulihkan'),
              _actionCard(
                icon: Icons.restore_rounded,
                title: 'Restore dari File',
                sub: 'Impor dari file JSON, ZIP, atau CSV',
                onTap: _restore,
              ),

              const SizedBox(height: 8),
              const SectionLabel('Hapus'),
              _actionCard(
                icon: Icons.delete_forever_rounded,
                title: 'Hapus Semua Data',
                sub: 'Produk dan transaksi dihapus permanen',
                color: C.danger,
                onTap: _clear,
              ),
            ],
          ),
        ), // ContentWidth
      ),
    );
  }
}

//  Settings Menu (hub menggantikan drawer)

class SettingsMenuPage extends StatefulWidget {
  const SettingsMenuPage({super.key});
  @override
  State<SettingsMenuPage> createState() => _SettingsMenuPageState();
}

class _SettingsMenuPageState extends State<SettingsMenuPage> {
  /// PC: section aktif di panel kanan
  String _pcSection = 'store'; // store | printer | staff | backup | about

  Widget _pcContent() {
    switch (_pcSection) {
      case 'printer':
        return const PrinterPage();
      case 'staff':
        return const StaffPage();
      case 'backup':
        return const BackupPage();
      case 'about':
        return const AboutPage();
      case 'store':
      default:
        return const SettingsPage();
    }
  }

  Widget _pcMenuItem({
    required IconData icon,
    required String title,
    required String id,
  }) {
    final active = _pcSection == id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: active ? C.brandLight : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _pcSection = id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: active ? C.brand : C.faint),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? C.brand : C.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _firstAllowedSection(App a) {
    if (a.canAccessMenu('settings')) return 'store';
    if (a.canAccessMenu('printer')) return 'printer';
    if (a.canAccessMenu('staff')) return 'staff';
    if (a.canAccessMenu('backup')) return 'backup';
    return 'about';
  }

  bool _sectionAllowed(App a, String id) {
    switch (id) {
      case 'store':
      case 'about':
        return a.canAccessMenu('settings');
      case 'printer':
        return a.canAccessMenu('printer');
      case 'staff':
        return a.canAccessMenu('staff');
      case 'backup':
        return a.canAccessMenu('backup');
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    final isPc = MediaQuery.sizeOf(context).width >= 1100;

    if (isPc) {
      // Jika section aktif tidak diizinkan, pindah ke yang boleh
      if (!_sectionAllowed(a, _pcSection)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _pcSection = _firstAllowedSection(a));
        });
      }
      return Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Menu kiri
              Container(
                width: 280,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: C.borderSoft)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: Text(
                        'Pengaturan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.brand,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.point_of_sale_rounded,
                                color: C.brand, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              a.storeName.isEmpty ? 'Toko Saya' : a.storeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // HPP toggle (hanya jika punya akses settings)
                    if (a.canAccessMenu('settings'))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                        child: Material(
                          color: C.surface,
                          borderRadius: BorderRadius.circular(12),
                          child: SwitchListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            dense: true,
                            title: const Text('Fitur HPP',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 12)),
                            value: a.hppEnabled,
                            activeThumbColor: C.brand,
                            onChanged: (v) =>
                                context.read<App>().setHppEnabled(v),
                          ),
                        ),
                      ),
                    if (a.canAccessMenu('settings') ||
                        a.canAccessMenu('printer') ||
                        a.canAccessMenu('staff') ||
                        a.canAccessMenu('backup')) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
                        child: Text('MANAJEMEN',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: C.muted,
                                letterSpacing: 0.6)),
                      ),
                      if (a.canAccessMenu('settings'))
                        _pcMenuItem(
                            icon: Icons.storefront_rounded,
                            title: 'Pengaturan Toko',
                            id: 'store'),
                      if (a.canAccessMenu('printer'))
                        _pcMenuItem(
                            icon: Icons.print_rounded,
                            title: 'Printer',
                            id: 'printer'),
                      if (a.canAccessMenu('staff'))
                        _pcMenuItem(
                            icon: Icons.people_outline_rounded,
                            title: 'Staff',
                            id: 'staff'),
                      if (a.canAccessMenu('backup'))
                        _pcMenuItem(
                            icon: Icons.backup_rounded,
                            title: 'Backup & Restore',
                            id: 'backup'),
                    ],
                    if (a.canAccessMenu('settings')) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
                        child: Text('LAINNYA',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: C.muted,
                                letterSpacing: 0.6)),
                      ),
                      if (a.canAccessMenu('settings'))
                        _pcMenuItem(
                            icon: Icons.info_outline_rounded,
                            title: 'Tentang',
                            id: 'about'),
                    ],
                  ],
                ),
              ),
              // Konten kanan
              Expanded(child: _pcContent()),
            ],
          ),
        ),
      );
    }

    // HP / tablet: list seperti sebelumnya
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              const PageHeader(
                title: 'Pengaturan',
                subtitle: 'Kelola toko, printer, staff & lainnya',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: C.brand,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.point_of_sale_rounded,
                          color: C.brand, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.storeName.isEmpty ? 'Toko Saya' : a.storeName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (a.storeAddress.isNotEmpty)
                            Text(
                              a.storeAddress,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (a.canAccessMenu('settings'))
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.borderSoft),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: C.brandLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.science_outlined,
                            color: C.brand, size: 20),
                      ),
                      title: const Text('Fitur HPP / Resep',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(
                        a.hppEnabled
                            ? 'Aktif - cocok untuk F&B, jus, makanan'
                            : 'Nonaktif - cocok untuk warung sembako',
                        style: const TextStyle(fontSize: 11, color: C.muted),
                      ),
                      value: a.hppEnabled,
                      activeThumbColor: C.brand,
                      onChanged: (v) => context.read<App>().setHppEnabled(v),
                    ),
                  ),
                ),
              if (a.canAccessMenu('settings') ||
                  a.canAccessMenu('printer') ||
                  a.canAccessMenu('staff') ||
                  a.canAccessMenu('backup')) ...[
                const SectionLabel('Manajemen'),
                if (a.canAccessMenu('settings'))
                  _SettingsTile(
                    icon: Icons.storefront_rounded,
                    title: 'Pengaturan Toko',
                    subtitle: 'Nama, alamat, kontak & pembayaran',
                    onTap: () => context.read<App>().setTab('Settings'),
                  ),
                if (a.canAccessMenu('printer'))
                  _SettingsTile(
                    icon: Icons.print_rounded,
                    title: 'Printer',
                    subtitle: 'Pengaturan printer Bluetooth',
                    onTap: () => context.read<App>().setTab('Printer'),
                  ),
                if (a.canAccessMenu('staff'))
                  _SettingsTile(
                    icon: Icons.people_outline_rounded,
                    title: 'Staff',
                    subtitle: 'Kelola karyawan',
                    onTap: () => context.read<App>().setTab('Staff'),
                  ),
                if (a.canAccessMenu('backup'))
                  _SettingsTile(
                    icon: Icons.backup_rounded,
                    title: 'Backup & Restore',
                    subtitle: 'Cadangan data',
                    onTap: () => context.read<App>().setTab('Backup'),
                  ),
              ],
              if (a.canAccessMenu('settings')) ...[
                const SizedBox(height: 16),
                const SectionLabel('Lainnya'),
                if (a.canAccessMenu('settings'))
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Tentang',
                    subtitle: 'Info aplikasi',
                    onTap: () => context.read<App>().setTab('About'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.borderSoft),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: C.brandLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: C.brand, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: C.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: C.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: C.faint.withValues(alpha: 0.7), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
