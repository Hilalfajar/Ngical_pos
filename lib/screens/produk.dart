import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app.dart';
import '../theme.dart';
import '../utils/formatter.dart';
import '../utils/toast.dart';

class ProdukPage extends StatefulWidget {
  const ProdukPage({super.key});
  @override
  State<ProdukPage> createState() => _ProdukPageState();
}

class _ProdukPageState extends State<ProdukPage> {
  final _q = TextEditingController();
  String query = '';

  /// PC: produk yang sedang diedit di panel kanan (null = mode tambah)
  Produk? _pcEditing;
  int _pcFormKey = 0; // force rebuild form saat ganti item

  bool _scanning = false;
  MobileScannerController? _scanCtrl;
  String? _lastScanned;
  Timer? _scanDebounce;
  static const _scanDelay = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
  }

  String _subtitle(App a) => '${a.produk.length} item terdaftar';

  bool get _canScanCamera {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  void _startScan() {
    if (!_canScanCamera) {
      AppToast.info(context,
          'Fitur scan barcode hanya tersedia di HP/Tablet Android & iOS');
      return;
    }
    _scanCtrl = MobileScannerController();
    setState(() => _scanning = true);
  }

  void _stopScan() {
    _scanCtrl?.dispose();
    _scanCtrl = null;
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _playScanBeep() async {
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  @override
  void dispose() {
    _q.dispose();
    _scanCtrl?.dispose();
    _scanDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    final list = a.produk.where((p) {
      if (query.isEmpty) return true;
      final s = query.toLowerCase();
      return p.nama.toLowerCase().contains(s) ||
          (p.barcode?.toLowerCase().contains(s) ?? false);
    }).toList();

    final sw = MediaQuery.sizeOf(context).width;
    final isPc = sw >= 1100;

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: isPc
            ? _buildPcLayout(a, list)
            : ContentWidth(
                child: Column(
                  children: [
                    // Header
                    PageHeader(
                      title: 'Produk',
                      subtitle: _subtitle(a),
                      trailing: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: C.brandLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: C.brand,
                          size: 22,
                        ),
                      ),
                    ),
                    // Scanner (mobile/tablet only)
                    if (!isPc && _scanning)
                        Container(
                          height: 180,
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.black,
                          ),
                          child: Stack(children: [
                            MobileScanner(
                              controller: _scanCtrl!,
                              onDetect: (capture) {
                                final barcode =
                                    capture.barcodes.firstOrNull?.rawValue;
                                if (barcode == null || barcode.isEmpty) return;

                                if (_lastScanned == barcode) return;
                                _lastScanned = barcode;
                                _scanDebounce?.cancel();
                                _scanDebounce = Timer(_scanDelay, () {
                                  _lastScanned = null;
                                });

                                _playScanBeep();
                                setState(() {
                                  _q.text = barcode;
                                  query = barcode;
                                  _scanning = false;
                                });
                                _stopScan();
                              },
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _stopScan,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                            const Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Text(
                                  'Arahkan ke barcode produk',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            ),
                          ]),
                        ),

                      // Search bar (produk saja)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: C.brand.withValues(alpha: 0.35),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: C.brand.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: C.brandLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.search_rounded,
                                    color: C.brand, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _q,
                                  onChanged: (v) => setState(() => query = v),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  decoration: const InputDecoration(
                                    hintText: 'Cari produk atau scan...',
                                    hintStyle: TextStyle(
                                      fontSize: 13,
                                      color: C.muted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              if (query.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _q.clear();
                                    setState(() => query = '');
                                  },
                                  child: const Icon(Icons.close_rounded,
                                      color: C.muted, size: 18),
                                ),
                              GestureDetector(
                                onTap: _scanning ? _stopScan : _startScan,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Icon(
                                    _scanning
                                        ? Icons.close
                                        : Icons.qr_code_scanner,
                                    color: _scanning ? C.danger : C.brand,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // List produk
                      Expanded(
                        child: list.isEmpty
                            ? _EmptyState(
                                message: query.isEmpty
                                    ? 'Belum ada produk.\nTap + untuk menambah.'
                                    : 'Tidak ditemukan.',
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 120),
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final p = list[i];
                                  return _ProdukTile(
                                    produk: p,
                                    onTap: () => _form(context, p: p),
                                    onEdit: () => _form(context, p: p),
                                    onDelete: () => _confirmDeleteProduk(p),
                                  );
                                },
                              ),
                      ),
                  ],
                ),
              ), // ContentWidth
      ),
      floatingActionButton: isPc
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton.extended(
                onPressed: () => _form(context),
                backgroundColor: C.brand,
                elevation: 4,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Tambah Produk',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
    );
  }

  /// Layout PC: produk body langsung (tanpa nav kiri)
  Widget _buildPcLayout(App a, List<Produk> list) {
    return _pcProdukBody(a, list);
  }

  /// Produk Jual: list + form (tanpa tab bar atas)
  Widget _pcProdukBody(App a, List<Produk> list) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            children: [
              PageHeader(title: 'Produk Jual', subtitle: _subtitle(a)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: C.brand.withValues(alpha: 0.35), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: C.brand.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: C.brandLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.search_rounded,
                            color: C.brand, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _q,
                          onChanged: (v) => setState(() => query = v),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(
                            hintText: 'Cari produk atau barcode...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: C.muted,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _q.clear();
                            setState(() => query = '');
                          },
                          child: const Icon(Icons.close_rounded,
                              color: C.muted, size: 18),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: C.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Scan / Cari',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: C.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: list.isEmpty
                    ? const Center(
                        child: Text('Belum ada produk',
                            style: TextStyle(color: C.muted)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final p = list[i];
                          final selected = _pcEditing?.id == p.id;
                          return Material(
                            color: selected ? C.brandLight : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _form(context, p: p),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(p.nama,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700)),
                                          Text(
                                            '${Formatter.rupiah(p.harga)} · Stok ${Formatter.qty(p.stok)}',
                                            style: const TextStyle(
                                                fontSize: 12, color: C.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Tombol hapus produk di PC
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _confirmDeleteProduk(p),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                            Icons.delete_outline_rounded,
                                            color:
                                                C.danger.withValues(alpha: 0.7),
                                            size: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right_rounded,
                                        color: selected ? C.brand : C.faint),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Container(width: 1, color: C.borderSoft),
        Expanded(
          flex: 5,
          child: ColoredBox(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _pcEditing == null ? 'Tambah Produk' : 'Edit Produk',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pcNewProduk,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Baru'),
                      ),
                      if (_pcEditing != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Hapus produk ini',
                          onPressed: () => _confirmDeleteProduk(_pcEditing!),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: C.danger, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: C.danger.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _ProdukForm(
                    key: ValueKey('pc-form-$_pcFormKey-${_pcEditing?.id}'),
                    produk: _pcEditing,
                    embedded: true,
                    onSaved: () => setState(() {
                      _pcEditing = null;
                      _pcFormKey++;
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteProduk(Produk p) async {
    final a = context.read<App>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus produk?'),
        content: Text('Produk "${p.nama}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await a.deleteProduk(p.id!);
      // Kalau produk yang dihapus sedang dibuka di panel kanan, reset form
      if (_pcEditing?.id == p.id) {
        setState(() {
          _pcEditing = null;
          _pcFormKey++;
        });
      }
    }
  }

  void _form(BuildContext context, {Produk? p}) {
    final w = MediaQuery.sizeOf(context).width;
    final isPc = w >= 1100;
    if (isPc) {
      setState(() {
        _pcEditing = p;
        _pcFormKey++;
      });
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProdukForm(produk: p),
    );
  }

  void _pcNewProduk() {
    setState(() {
      _pcEditing = null;
      _pcFormKey++;
    });
  }
}

//  Product tile

class _ProdukTile extends StatelessWidget {
  final Produk produk;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProdukTile({
    required this.produk,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = produk;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: C.brand.withValues(alpha: 0.35), width: 1.5),
            boxShadow: cardShadow,
          ),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: C.brandLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: p.foto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(File(p.foto!), fit: BoxFit.cover),
                      )
                    : const Icon(Icons.inventory_2_rounded,
                        color: C.brand, size: 26),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nama,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: C.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          Formatter.rupiah(p.harga),
                          style: const TextStyle(
                            color: C.brand,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.stok > 0 ? C.successSoft : C.dangerSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Stok ${Formatter.qty(produk.stok)} ${produk.satuan}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: produk.stok > 0 ? C.success : C.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Menu
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18, color: C.text2),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18, color: C.danger),
                      SizedBox(width: 10),
                      Text('Hapus', style: TextStyle(color: C.danger)),
                    ]),
                  ),
                ],
                icon: const Icon(Icons.more_vert_rounded,
                    color: C.faint, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//  Empty state

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: C.brandLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 36, color: C.brand),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: C.muted, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

//  Form Tambah / Edit Produk

class _ProdukForm extends StatefulWidget {
  final Produk? produk;
  final bool embedded;
  final VoidCallback? onSaved;
  const _ProdukForm({
    super.key,
    this.produk,
    this.embedded = false,
    this.onSaved,
  });
  @override
  State<_ProdukForm> createState() => _ProdukFormState();
}

class _ProdukFormState extends State<_ProdukForm> {
  late final TextEditingController _nama;
  late final TextEditingController _barcode;
  late final TextEditingController _modal;
  late final TextEditingController _harga;
  late final TextEditingController _stok;
  String _satuan = 'pcs';
  String? _kategori;

  /// draft harga paket / grosir
  final List<HargaTier> _tiers = [];

  String? _fotoPath;
  bool _scanning = false;
  MobileScannerController? _scanCtrl;
  final _urlCtrl = TextEditingController();
  bool _downloadingUrl = false;
  String? _urlError;

  @override
  void initState() {
    super.initState();
    final p = widget.produk;
    _nama = TextEditingController(text: p?.nama ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _modal = TextEditingController(text: p != null ? '${p.hargaModal}' : '');
    _harga = TextEditingController(text: p != null ? '${p.harga}' : '');
    _stok = TextEditingController(text: p != null ? '${p.stok}' : '');
    _satuan = p?.satuan ?? 'pcs';
    _fotoPath = p?.foto;
    _kategori = p?.kategori;
    if (p?.id != null) {
      final app = context.read<App>();
      _tiers.addAll(app.tiersOf(p!.id!));
    }
  }

  @override
  void dispose() {
    _nama.dispose();
    _barcode.dispose();
    _modal.dispose();
    _harga.dispose();
    _stok.dispose();
    _urlCtrl.dispose();
    _scanCtrl?.dispose();
    super.dispose();
  }

  bool get _isDesktop {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file != null) setState(() => _fotoPath = file.path);
  }

  /// PC: langsung File Explorer. HP: image_picker galeri/kamera.
  Future<void> _pickImageDesktop() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (files.isNotEmpty) {
      setState(() => _fotoPath = files.single.path);
    }
  }

  /// Ubah link Google Drive share → direct download bila perlu
  String _normalizeImageUrl(String raw) {
    var url = raw.trim();
    // drive.google.com/file/d/ID/view...
    final driveFile =
        RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (driveFile != null) {
      return 'https://drive.google.com/uc?export=download&id=${driveFile.group(1)}';
    }
    // drive.google.com/open?id=ID
    final driveOpen = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (url.contains('drive.google.com') && driveOpen != null) {
      return 'https://drive.google.com/uc?export=download&id=${driveOpen.group(1)}';
    }
    return url;
  }

  Future<void> _downloadFromUrl(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      setState(() => _urlError = 'Link harus diawali http:// atau https://');
      return;
    }
    if (_downloadingUrl) return;

    setState(() {
      _downloadingUrl = true;
      _urlError = null;
    });

    try {
      final url = _normalizeImageUrl(trimmed);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'Mozilla/5.0 (compatible; NgicalPOS/1.0)');
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Gagal unduh (${res.statusCode})');
      }
      final bytes = await res
          .fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));
      if (bytes.length < 100) {
        throw Exception('File terlalu kecil / bukan gambar');
      }
      // Cek magic bytes sederhana
      final isJpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
      final isPng = bytes.length > 3 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E;
      final isGif = bytes.length > 3 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46;
      final isWebp = bytes.length > 11 && bytes[0] == 0x52 && bytes[8] == 0x57;
      if (!isJpeg && !isPng && !isGif && !isWebp) {
        throw Exception('Link bukan file gambar');
      }
      final ext = isPng
          ? 'png'
          : isGif
              ? 'gif'
              : isWebp
                  ? 'webp'
                  : 'jpg';
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/product_images');
      if (!await folder.exists()) await folder.create(recursive: true);
      final filePath =
          '${folder.path}/img_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(filePath).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _fotoPath = filePath;
        _downloadingUrl = false;
        _urlError = null;
      });
      client.close(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadingUrl = false;
        _urlError = 'Gagal unduh: $e';
      });
    }
  }

  void _onUrlChanged(String value) {
    final v = value.trim();
    if (v.startsWith('http://') || v.startsWith('https://')) {
      // Auto download saat paste link lengkap
      _downloadFromUrl(v);
    }
  }

  Widget _urlPasteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Text(
          'atau paste link Google Drive / URL gambar:',
          style: TextStyle(fontSize: 12, color: C.muted),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _urlCtrl,
          onChanged: _onUrlChanged,
          onSubmitted: _downloadFromUrl,
          decoration: InputDecoration(
            hintText: 'https://drive.google.com/file/d/...',
            hintStyle: const TextStyle(fontSize: 13, color: C.faint),
            prefixIcon: _downloadingUrl
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.link, size: 20, color: C.muted),
            suffixIcon: _urlCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _urlCtrl.clear();
                      setState(() => _urlError = null);
                    },
                  )
                : null,
            filled: true,
            fillColor: C.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: C.borderSoft),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: C.borderSoft),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: C.brand, width: 1.5),
            ),
          ),
        ),
        if (_urlError != null) ...[
          const SizedBox(height: 6),
          Text(_urlError!,
              style: const TextStyle(fontSize: 11, color: C.danger)),
        ],
      ],
    );
  }

  void _startScan() {
    _scanCtrl = MobileScannerController();
    setState(() => _scanning = true);
  }

  void _stopScan() {
    _scanCtrl?.dispose();
    _scanCtrl = null;
    setState(() => _scanning = false);
  }

  Future<void> _addTierDialog() async {
    final qtyCtrl = TextEditingController();
    final hargaCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Harga Paket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Qty paket (mis. 3 / 5 / 13)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hargaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga total paket (Rp)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Label (opsional, mis. Renceng)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tambah')),
        ],
      ),
    );
    if (ok != true) return;
    final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    final h = int.tryParse(hargaCtrl.text) ?? 0;
    if (q <= 0 || h <= 0) {
      AppToast.error(context, 'Qty dan harga harus > 0');
      return;
    }
    setState(() {
      _tiers.add(HargaTier(
        minQty: q,
        harga: h,
        label: labelCtrl.text.trim(),
      ));
      _tiers.sort((a, b) => a.minQty.compareTo(b.minQty));
    });
  }

  Widget _buildTierSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.sell_outlined, size: 16, color: C.brand),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Harga Paket / Grosir',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            TextButton.icon(
              onPressed: _addTierDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah'),
              style: TextButton.styleFrom(
                foregroundColor: C.brand,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        if (_tiers.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.borderSoft),
            ),
            child: const Text(
                'Contoh: Beli 3 = Rp10.000. Belum ada paket harga.',
                style: TextStyle(fontSize: 12, color: C.muted)),
          )
        else
          ..._tiers.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            final label = t.label.isNotEmpty ? t.label : 'Paket';
            return Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.borderSoft),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4)
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$label · ${Formatter.qty(t.minQty)} pcs = ${Formatter.rupiah(t.harga)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: C.text),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _tiers.removeAt(i)),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: C.danger, size: 20),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Future<void> _save() async {
    final n = _nama.text.trim();
    final h = int.tryParse(_harga.text) ?? 0;
    final s = double.tryParse(_stok.text) ?? 0.0;
    final a = context.read<App>();
    final m = int.tryParse(_modal.text) ?? 0;
    if (n.isEmpty || h <= 0) return;
    await a.saveProduk(
      Produk(
        id: widget.produk?.id,
        nama: n,
        satuan: _satuan,
        barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        hargaModal: m,
        harga: h,
        stok: s,
        foto: _fotoPath,
        kategori: _kategori?.trim().isEmpty == true ? null : _kategori?.trim(),
      ),
      tiers: List<HargaTier>.from(_tiers),
    );
    if (!mounted) return;
    if (widget.embedded) {
      widget.onSaved?.call();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.produk != null;
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height * 0.9;
    final maxW = mq.size.width > 640 ? 560.0 : mq.size.width;

    final embedded = widget.embedded;

    if (embedded) {
      // Panel kanan PC: full height scroll (isi form sama)
      return Material(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: _buildEmbeddedScroll(isEdit),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: C.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEdit ? 'Edit Produk' : 'Tambah Produk',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: C.text,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: C.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: C.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                // Body - Expanded butuh tinggi terbatas (dari ConstrainedBox)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Photo
                        GestureDetector(
                          onTap: () => _showImageOptions(context),
                          child: Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color: C.surface,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: C.borderSoft),
                            ),
                            child: _fotoPath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: Image.file(File(_fotoPath!),
                                        fit: BoxFit.cover,
                                        width: double.infinity),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined,
                                          size: 40, color: C.faint),
                                      SizedBox(height: 8),
                                      Text('Tambah foto produk',
                                          style: TextStyle(
                                              color: C.muted, fontSize: 13)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_isDesktop)
                          OutlinedButton.icon(
                            onPressed: _pickImageDesktop,
                            icon: const Icon(Icons.folder_open_outlined,
                                size: 18),
                            label: const Text('Pilih File Gambar'),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _pickImage(ImageSource.gallery),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(28)),
                                  ),
                                  icon: const Icon(Icons.photo_library_outlined,
                                      size: 18),
                                  label: const Text('Galeri'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _pickImage(ImageSource.camera),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(28)),
                                  ),
                                  icon: const Icon(Icons.camera_alt_outlined,
                                      size: 18),
                                  label: const Text('Kamera'),
                                ),
                              ),
                            ],
                          ),
                        _urlPasteField(),
                        const SizedBox(height: 18),
                        _field(_nama,
                            label: 'Nama Produk', hint: 'Contoh: Kopi Susu'),
                        const SizedBox(height: 14),
                        Builder(builder: (context) {
                          final cats = context.watch<App>().uniqueKategori;
                          return _buildKategoriField(cats);
                        }),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _field(_barcode,
                                  label: 'Barcode', hint: 'Opsional'),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _scanning ? _stopScan : _startScan,
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color:
                                      _scanning ? C.dangerSoft : C.brandLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _scanning ? C.danger : C.brand,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  _scanning
                                      ? Icons.close_rounded
                                      : Icons.qr_code_scanner_rounded,
                                  color: _scanning ? C.danger : C.brand,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_scanning) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 200,
                              child: MobileScanner(
                                controller: _scanCtrl!,
                                onDetect: (capture) {
                                  final barcode =
                                      capture.barcodes.firstOrNull?.rawValue;
                                  if (barcode != null && barcode.isNotEmpty) {
                                    _barcode.text = barcode;
                                    _stopScan();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                                child: _field(_modal,
                                    label: 'Harga Modal',
                                    hint: '0',
                                    numeric: true)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _field(_harga,
                                    label: 'Harga Jual',
                                    hint: '0',
                                    numeric: true)),
                          ],
                        ),

                        _buildTierSection(),

                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _field(_stok,
                                  label: 'Stok Saat Ini',
                                  hint: '0',
                                  numeric: true,
                                  decimal: true),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Satuan',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: C.muted,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: C.surface,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _satuan,
                                        isExpanded: true,
                                        icon: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: C.muted),
                                        items: [
                                          'pcs',
                                          'kg',
                                          'gram',
                                          'porsi',
                                          'liter',
                                          'ikat',
                                          'box'
                                        ]
                                            .map((e) => DropdownMenuItem(
                                                  value: e,
                                                  child: Text(e,
                                                      style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500)),
                                                ))
                                            .toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() => _satuan = v);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: C.brand,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28)),
                              elevation: 0,
                            ),
                            child: Text(
                              isEdit ? 'Simpan Perubahan' : 'Simpan Produk',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildEmbeddedScroll(bool isEdit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo
          GestureDetector(
            onTap: () => _showImageOptions(context),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: C.borderSoft),
              ),
              child: _fotoPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(File(_fotoPath!),
                          fit: BoxFit.cover, width: double.infinity),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 36, color: C.faint),
                        SizedBox(height: 6),
                        Text('Tambah foto produk',
                            style: TextStyle(color: C.muted, fontSize: 12)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _urlPasteField(),
          const SizedBox(height: 16),
          _field(_nama, label: 'Nama Produk', hint: 'Contoh: Kopi Susu'),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final cats = context.watch<App>().uniqueKategori;
            return _buildKategoriField(cats);
          }),
          const SizedBox(height: 12),
          _field(_barcode, label: 'Barcode', hint: 'Opsional'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _field(_modal,
                      label: 'Harga Modal', hint: '0', numeric: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(_harga,
                      label: 'Harga Jual', hint: '0', numeric: true)),
            ],
          ),
          _buildTierSection(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(_stok,
                    label: 'Stok', hint: '0', numeric: true, decimal: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Satuan',
                      style: TextStyle(
                          fontSize: 12,
                          color: C.muted,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      height: 48,
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _satuan,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: C.muted),
                          items: [
                            'pcs',
                            'kg',
                            'gram',
                            'porsi',
                            'liter',
                            'ikat',
                            'box'
                          ]
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _satuan = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: C.brand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                isEdit ? 'Simpan Perubahan' : 'Simpan Produk',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageOptions(BuildContext context) {
    // Mode PC: langsung buka File Explorer, tanpa popup
    if (_isDesktop) {
      _pickImageDesktop();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.photo_library_outlined, color: C.brand),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: C.brand),
                title: const Text('Ambil Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_fotoPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: C.danger),
                  title: const Text('Hapus Foto',
                      style: TextStyle(color: C.danger)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _fotoPath = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKategoriField(List<String> kategoriList) {
    final radius = widget.embedded ? 14.0 : 28.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Kategori',
              style: TextStyle(
                  fontSize: 12, color: C.muted, fontWeight: FontWeight.w600)),
        ),
        GestureDetector(
          onTap: () => _showKategoriPicker(kategoriList, radius),
          child: Container(
            height: 48,
            padding:
                EdgeInsets.symmetric(horizontal: widget.embedded ? 16 : 20),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  _kategori ?? 'Opsional, pilih atau buat baru',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _kategori != null ? C.text : C.faint,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_kategori != null)
                GestureDetector(
                  onTap: () => setState(() => _kategori = null),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.close_rounded, size: 16, color: C.muted),
                  ),
                )
              else
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: C.muted),
            ]),
          ),
        ),
      ],
    );
  }

  void _showKategoriPicker(List<String> existing, double radius) {
    final searchCtrl = TextEditingController();
    List<String> filtered = List.from(existing);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          void doFilter(String q) {
            setModal(() {
              filtered = q.trim().isEmpty
                  ? List.from(existing)
                  : existing
                      .where((k) =>
                          k.toLowerCase().contains(q.trim().toLowerCase()))
                      .toList();
            });
          }

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: C.border,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Pilih Kategori',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  // Search + tambah baru
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: doFilter,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cari atau ketik kategori baru...',
                      hintStyle: const TextStyle(color: C.faint, fontSize: 13),
                      filled: true,
                      fillColor: C.surface,
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: C.muted, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: C.brand, width: 1.5)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tombol "Tambah baru" jika ketikan tidak ada di list
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: searchCtrl,
                    builder: (_, val, __) {
                      final q = val.text.trim();
                      final belumAda = q.isNotEmpty &&
                          !existing
                              .any((k) => k.toLowerCase() == q.toLowerCase());
                      if (!belumAda) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: C.brandLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: C.brand, size: 20),
                          ),
                          title: Text('Tambah "$q"',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: C.brand)),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() => _kategori = q);
                          },
                        ),
                      );
                    },
                  ),
                  // List kategori yang ada
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                    ),
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Belum ada kategori.',
                                style: TextStyle(color: C.muted, fontSize: 13)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final k = filtered[i];
                              final active = _kategori == k;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: active ? C.brand : C.surface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.label_outline_rounded,
                                    color: active ? Colors.white : C.muted,
                                    size: 18,
                                  ),
                                ),
                                title: Text(k,
                                    style: TextStyle(
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 14,
                                    )),
                                trailing: active
                                    ? const Icon(Icons.check_rounded,
                                        color: C.brand, size: 18)
                                    : null,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  setState(() => _kategori = k);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController ctrl,
          {String label = '',
          String hint = '',
          bool numeric = false,
          bool decimal = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: C.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextField(
            controller: ctrl,
            keyboardType: numeric
                ? TextInputType.numberWithOptions(decimal: decimal)
                : TextInputType.text,
            style: const TextStyle(
                fontSize: 14, color: C.text, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: C.faint, fontSize: 13),
              filled: true,
              fillColor: C.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.embedded ? 14 : 28),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.embedded ? 14 : 28),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.embedded ? 14 : 28),
                borderSide: BorderSide(
                    color: C.brand, width: widget.embedded ? 1.5 : 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: widget.embedded ? 16 : 20,
                  vertical: widget.embedded ? 14 : 15),
              isDense: true,
            ),
          ),
        ],
      );
}


