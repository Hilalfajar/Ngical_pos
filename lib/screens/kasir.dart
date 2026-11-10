import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/models.dart';
import '../providers/app.dart';
import '../services/printer_service.dart';
import '../theme.dart';
import '../utils/formatter.dart';
import '../utils/toast.dart';
import '../utils/qris_dynamic.dart';

class KasirPage extends StatefulWidget {
  const KasirPage({super.key});
  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> {
  final _q = TextEditingController();
  final _focusNode = FocusNode();
  String query = '';
  bool _scanning = false;
  MobileScannerController? _scanCtrl;
  final _beepPlayer = AudioPlayer();

  // Debounce scan  cegah qty naik terlalu cepat
  String? _lastScanned;
  Timer? _scanDebounce;
  static const _scanDelay = Duration(milliseconds: 1200);

  Future<void> _playScanBeep() async {
    try {
      await _beepPlayer.stop();
      await _beepPlayer.play(AssetSource('sounds/beep.wav'));
    } catch (_) {
      // Fallback jika asset gagal dimuat
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  void initState() {
    super.initState();
    // Unfocus otomatis saat keyboard dismiss
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _q.text.isNotEmpty) {
        // Klik kembali ke search → select-all agar ketik baru langsung ganti
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_focusNode.hasFocus) return;
          final t = _q.text;
          if (t.isEmpty) return;
          _q.selection = TextSelection(baseOffset: 0, extentOffset: t.length);
        });
      }
    });
  }

  @override
  void dispose() {
    _q.dispose();
    _focusNode.dispose();
    _scanCtrl?.dispose();
    _scanDebounce?.cancel();
    _beepPlayer.dispose();
    super.dispose();
  }

  List<Produk> _filter(List<Produk> all) {
    if (query.isEmpty) return all;
    final s = query.toLowerCase();
    return all
        .where((p) =>
            p.nama.toLowerCase().contains(s) ||
            (p.barcode?.toLowerCase().contains(s) ?? false))
        .toList();
  }

  void _openSheet(BuildContext ctx) {
    // Unfocus / tutup keyboard sebelum buka sheet
    _focusNode.unfocus();
    FocusScope.of(ctx).unfocus();
    final a = ctx.read<App>();
    a.setSheet(true);
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CartSheet(),
    ).whenComplete(() => a.setSheet(false));
  }

  void _startScan() {
    if (kIsWeb) {
      AppToast.info(context, 'Fitur scan tidak tersedia di Web');
      return;
    }
    try {
      if (!(Platform.isAndroid || Platform.isIOS)) {
        AppToast.info(context,
            'Fitur scan barcode hanya tersedia di HP/Tablet Android & iOS');
        return;
      }
    } catch (_) {
      return;
    }
    _scanCtrl = MobileScannerController();
    setState(() => _scanning = true);
  }

  void _stopScan() {
    _scanCtrl?.dispose();
    _scanCtrl = null;
    setState(() => _scanning = false);
  }

  Widget _buildBottomBar({
    required double sw,
    required double bottom,
    required bool navExpanded,
    required App a,
  }) {
    final changed = a.navExpandedChanged;
    if (changed) a.consumeNavChange();
    final endVal = navExpanded ? 1.0 : 0.0;
    final beginVal = changed ? (navExpanded ? 0.0 : 1.0) : endVal;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: beginVal, end: endVal),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Transform.translate(
        offset: Offset(0, -(sw > 600 ? 72.0 : 68.0) * t),
        child: child,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, bottom > 0 ? 0 : 4),
        decoration: const BoxDecoration(
          color: C.brand,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: C.brand.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Row(children: [
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: C.brandLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.search_rounded, color: C.brand, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _q,
                  focusNode: _focusNode,
                  onChanged: (v) => setState(() => query = v),
                  onSubmitted: (_) => _focusNode.unfocus(),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: 'Cari produk atau scan...',
                    hintStyle: TextStyle(
                        fontSize: 13,
                        color: C.muted,
                        fontWeight: FontWeight.w500),
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
                    _focusNode.requestFocus();
                  },
                  child:
                      const Icon(Icons.close_rounded, color: C.muted, size: 18),
                ),
              GestureDetector(
                onTap: _scanning ? _stopScan : _startScan,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    _scanning ? Icons.close : Icons.qr_code_scanner,
                    color: _scanning ? C.danger : C.brand,
                    size: 20,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _openSheet(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.only(top: 6, bottom: bottom),
              child: Row(children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.shopping_cart_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${Formatter.qty(a.cartQty)} Item',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text('Total Belanja',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 10)),
                      ]),
                ]),
                const Spacer(),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(Formatter.rupiah(a.cartTotal),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Icon(Icons.chevron_right,
                      color: Colors.white, size: 18),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    final list = _filter(a.produk);
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final sw = MediaQuery.of(context).size.width;

    // Tablet threshold
    final isTablet = sw > 900;

    // Responsive: jumlah kolom tergantung lebar layar
    // Di mode tablet, grid produk lebih sempit karena ada panel kanan (max 420)
    final cartW = isTablet ? (sw * 0.34).clamp(360.0, 420.0) : 0.0;
    final gridWidth = isTablet ? (sw - cartW - 1) : sw;
    final crossCount = gridWidth < 480
        ? 2
        : gridWidth < 800
            ? 3
            : gridWidth < 1100
                ? 4
                : 5;
    // Aspect ratio lebih “pendek” supaya teks nama/harga/stok tidak overflow
    final childAspect = gridWidth < 480 ? 0.78 : 0.84;

    Widget buildTabletSearchBar() {
      final isLaptop = sw >= 1100;
      // Search lebih menonjol di tablet/PC
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isLaptop ? 14 : 28),
            border:
                Border.all(color: C.brand.withValues(alpha: 0.35), width: 1.5),
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
                child:
                    const Icon(Icons.search_rounded, color: C.brand, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _q,
                  focusNode: _focusNode,
                  onChanged: (v) => setState(() => query = v),
                  onSubmitted: (v) {
                    final code = v.trim();
                    if (code.isEmpty) return;
                    final a = context.read<App>();
                    final before = a.cartQty;
                    a.addCartByBarcode(code);
                    if (a.cartQty > before) {
                      unawaited(_playScanBeep());
                      _q.clear();
                      setState(() => query = '');
                    }
                    _focusNode.requestFocus();
                  },
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: 'Cari produk atau scan barcode...',
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
                    _focusNode.requestFocus();
                  },
                  child:
                      const Icon(Icons.close_rounded, color: C.muted, size: 18),
                ),
              GestureDetector(
                onTap: _scanning ? _stopScan : _startScan,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    _scanning ? Icons.close : Icons.qr_code_scanner,
                    color: _scanning ? C.danger : C.brand,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildMainContent() {
      return Column(children: [
        SizedBox(height: top + 4),
        // Tablet/PC: search di atas grid
        if (isTablet) buildTabletSearchBar(),
        // Scanner kamera
        if (_scanning)
          Container(
            height: 180,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.black,
            ),
            child: Stack(children: [
              MobileScanner(
                controller: _scanCtrl!,
                onDetect: (capture) {
                  final barcode = capture.barcodes.firstOrNull?.rawValue;
                  if (barcode == null || barcode.isEmpty) return;

                  // Debounce: abaikan scan yang sama dalam 1.2 detik
                  if (_lastScanned == barcode) return;
                  _lastScanned = barcode;
                  _scanDebounce?.cancel();
                  _scanDebounce = Timer(_scanDelay, () {
                    _lastScanned = null;
                  });

                  final a = context.read<App>();
                  final before = a.cartQty;
                  a.addCartByBarcode(barcode);
                  final after = a.cartQty;

                  if (after > before) {
                    HapticFeedback.mediumImpact();
                    unawaited(_playScanBeep()); // bunyi scanner gun
                    final produk = a.produk
                        .where((p) =>
                            p.barcode?.toLowerCase() == barcode.toLowerCase())
                        .firstOrNull;
                    if (mounted) {
                      AppToast.show(
                        context,
                        '+ ${produk?.nama ?? barcode}',
                        type: ToastType.success,
                        duration: const Duration(seconds: 1),
                      );
                    }
                  } else {
                    HapticFeedback.heavyImpact();
                    SystemSound.play(SystemSoundType.alert);
                    if (mounted) {
                      AppToast.show(
                        context,
                        'Produk tidak ditemukan: $barcode',
                        type: ToastType.error,
                        duration: const Duration(seconds: 2),
                      );
                    }
                  }
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
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 18),
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
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ]),
          ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text('Belum ada produk.\nTambah di menu Produk.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: C.muted)))
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                      12,
                      4,
                      12,
                      isTablet
                          ? 12
                          : (_scanning ? 160 : (a.navExpanded ? 280 : 200))),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: childAspect,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final qty = a.cart[p.id]?.qty ?? 0;
                    return _Card(
                        p: p,
                        qty: qty,
                        onTap: () {
                          a.addCart(p);
                        });
                  },
                ),
        ),
        // Bottom bar (only for mobile)
        if (!isTablet)
          _buildBottomBar(
            sw: sw,
            bottom: bottom,
            navExpanded: a.navExpanded,
            a: a,
          ),
      ]);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: ColoredBox(
        color: C.bg,
        child: isTablet
            ? Row(children: [
                Expanded(child: buildMainContent()),
                const VerticalDivider(width: 1, color: C.borderSoft),
                // Sidebar keranjang: lebar tetap (tidak ikut meledak di monitor besar)
                SizedBox(
                  width: (sw * 0.34).clamp(360.0, 420.0),
                  child: const _CartSheet(isTablet: true),
                ),
              ])
            : Stack(children: [
                // Pengisi biru di bawah panel agar tidak ada gap putih
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: (sw > 600 ? 72.0 : 68.0) + bottom + 16,
                  child: const ColoredBox(color: C.brand),
                ),
                buildMainContent(),
              ]),
      ),
    );
  }
}

//  Product Card

class _Card extends StatelessWidget {
  final Produk p;
  final double qty;
  final VoidCallback onTap;
  const _Card({required this.p, required this.qty, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: p.stok > 0 ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: p.foto != null ? Colors.transparent : C.brandLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(children: [
                  if (p.foto != null && File(p.foto!).existsSync())
                    Positioned.fill(
                      child: Image.file(File(p.foto!), fit: BoxFit.cover),
                    )
                  else
                    const Center(
                        child:
                            Icon(Icons.inventory_2, color: C.brand, size: 28)),
                  if (qty > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: C.brand,
                        child: Text(Formatter.qty(qty.toDouble()),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9)),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 5),
            Text(p.nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12, color: C.text)),
            Text(Formatter.rupiah(p.harga),
                style: const TextStyle(
                    color: C.brand, fontWeight: FontWeight.bold, fontSize: 12)),
            Text('Stok: ${p.stok} ${p.satuan}',
                style: TextStyle(
                    color: p.stok > 0 ? C.muted : C.danger, fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}

//  Cart Sheet / Panel

class _CartSheet extends StatefulWidget {
  final bool isTablet;
  const _CartSheet({this.isTablet = false});
  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final _uang = TextEditingController();
  String _metode = 'cash'; // 'cash' | 'qris' | 'transfer' | 'hutang'
  final _namaHutang = TextEditingController();
  int _lastAutoTotal =
      -1; // track total terakhir yang di-auto-isi ke uang tunai

  @override
  void initState() {
    super.initState();
    final t = context.read<App>().cartTotal;
    _uang.text = t.toString();
    _lastAutoTotal = t;
  }

  @override
  void dispose() {
    _uang.dispose();
    _namaHutang.dispose();
    super.dispose();
  }

  Future<void> _pay({bool manualPrint = false}) async {
    final a = context.read<App>();
    if (a.cartTotal <= 0) return;

    final snapshotItems = a.cart.values
        .map((c) => ReceiptLine(
            nama: c.nama, qty: c.qty, harga: c.harga, subtotal: c.subtotal))
        .toList();
    final snapshotTotal = a.cartTotal;

    // Helper: tutup sheet hanya di mode HP (modal). Di tablet panel tetap terbuka.
    void closeIfNeeded() {
      if (!widget.isTablet && mounted) {
        Navigator.pop(context);
      }
    }

    // Reset form lokal setelah bayar sukses (penting di tablet)
    void resetForm() {
      _metode = 'cash';
      _uang.text = '0';
      _lastAutoTotal = 0;
      _namaHutang.clear();
      if (mounted) setState(() {});
    }

    if (_metode == 'hutang') {
      final nama = _namaHutang.text.trim();
      if (nama.isEmpty) {
        AppToast.error(context, 'Isi nama yang berhutang');
        return;
      }
      final k = await a.bayar(
        0,
        metode: 'hutang',
        status: 'hutang',
        namaHutang: nama,
      );
      if (!mounted) return;
      if (k != null) {
        AppToast.success(
          context,
          'Hutang $nama tercatat. Stok sudah dipotong, belum masuk laporan.',
          title: 'Hutang Disimpan',
        );
      }
      closeIfNeeded();
      resetForm();
      return;
    }

    if (_metode == 'cash') {
      final tunai = int.tryParse(_uang.text) ?? 0;
      if (tunai < a.cartTotal) {
        AppToast.error(context, 'Uang tunai kurang dari total belanja');
        return;
      }
      final k = await a.bayar(tunai, metode: 'cash');
      if (!mounted) return;

      if (manualPrint && !a.printerAutoPrint && k != null) {
        unawaited(a.cetakStruk(
          items: snapshotItems,
          total: snapshotTotal,
          bayar: tunai,
          kembalian: k,
          metode: 'cash',
        ));
      }

      if (k != null) {
        AppToast.success(context, 'Kembalian: ${Formatter.rupiah(k)}',
            title: 'Pembayaran Berhasil');
      }
      closeIfNeeded();
      resetForm();
    } else {
      final k = await a.bayar(a.cartTotal, metode: _metode);
      if (!mounted) return;

      if (manualPrint && !a.printerAutoPrint && k != null) {
        unawaited(a.cetakStruk(
          items: snapshotItems,
          total: snapshotTotal,
          bayar: snapshotTotal,
          kembalian: 0,
          metode: _metode,
        ));
      }

      if (k != null) {
        AppToast.success(
            context, 'Transaksi ${_metode.toUpperCase()} berhasil dicatat',
            title: 'Pembayaran Berhasil');
      }
      closeIfNeeded();
      resetForm();
    }
  }

  void _editQty(BuildContext context, CartItem item) {
    final a = context.read<App>();
    final qtyCtrl = TextEditingController(text: Formatter.qty(item.qty));
    final totalCtrl = TextEditingController(
        text: HargaTier.lineTotal(item.qty, item.harga, item.tiers).toString());
    final isMass =
        ['kg', 'gram', 'g', 'ons'].contains(item.satuan.toLowerCase());
    // Cegah loop: 'qty' | 'total' | null
    String? editingField;

    /// Hitung qty dari total Rp (dukung tier via binary search).
    double qtyFromTotal(int targetRp) {
      if (targetRp <= 0) return 0;
      if (item.tiers.isEmpty) {
        if (item.harga <= 0) return 0;
        return targetRp / item.harga;
      }
      // Cari qty agar lineTotal mendekati targetRp
      double lo = 0;
      double hi = (item.harga > 0 ? targetRp / item.harga : 1) * 4 + 100;
      for (int i = 0; i < 48; i++) {
        final mid = (lo + hi) / 2;
        final t = HargaTier.lineTotal(mid, item.harga, item.tiers);
        if (t < targetRp) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return hi;
    }

    void syncFromQty(void Function(void Function()) setModal) {
      final input = qtyCtrl.text.replaceAll(',', '.');
      final val = double.tryParse(input) ?? 0;
      final sub = HargaTier.lineTotal(val, item.harga, item.tiers);
      totalCtrl.text = sub > 0 ? sub.toString() : '';
      setModal(() {});
    }

    void syncFromTotal(void Function(void Function()) setModal) {
      // Terima "13000" atau "13.000"
      final digits = totalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final target = int.tryParse(digits) ?? 0;
      final qty = qtyFromTotal(target);
      // Format qty: max 3 desimal, buang trailing zero
      String fmt(double q) {
        if (q <= 0) return '';
        final s = q.toStringAsFixed(3);
        return s.replaceFirst(RegExp(r'\.?0+$'), '');
      }
      qtyCtrl.text = fmt(qty);
      setModal(() {});
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        final input = qtyCtrl.text.replaceAll(',', '.');
        final val = double.tryParse(input) ?? 0;

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Input Jumlah (${item.satuan})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Qty ──
              TextField(
                controller: qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                onChanged: (_) {
                  if (editingField == 'total') return;
                  editingField = 'qty';
                  syncFromQty(setModal);
                  editingField = null;
                },
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Jumlah',
                  hintText: '0.00',
                  suffixText: item.satuan,
                  filled: true,
                  fillColor: C.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              if (isMass) ...[
                const Text('Pilihan Cepat:',
                    style: TextStyle(fontSize: 11, color: C.muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    _quickQty(ctx, '1/4', 0.25, qtyCtrl, () {
                      editingField = 'qty';
                      syncFromQty(setModal);
                      editingField = null;
                    }),
                    _quickQty(ctx, '1/2', 0.5, qtyCtrl, () {
                      editingField = 'qty';
                      syncFromQty(setModal);
                      editingField = null;
                    }),
                    _quickQty(ctx, '3/4', 0.75, qtyCtrl, () {
                      editingField = 'qty';
                      syncFromQty(setModal);
                      editingField = null;
                    }),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // ── Total Rp (bisa diedit → qty ikut) ──
              TextField(
                controller: totalCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (editingField == 'qty') return;
                  editingField = 'total';
                  syncFromTotal(setModal);
                  editingField = null;
                },
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18, color: C.brand),
                decoration: InputDecoration(
                  labelText: 'Total (Rp)',
                  hintText: '0',
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: C.brandLight,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.harga > 0
                    ? 'Harga satuan: ${Formatter.rupiah(item.harga)} / ${item.satuan}'
                    : '',
                style: const TextStyle(fontSize: 11, color: C.muted),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: C.brand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: val <= 0
                  ? null
                  : () {
                      a.updateCartQty(item.produkId, val);
                      Navigator.pop(ctx);
                    },
              child: const Text('Simpan'),
            ),
          ],
        );
      }),
    );
  }

  Widget _quickQty(BuildContext ctx, String label, double val,
      TextEditingController ctrl, VoidCallback onUpdate) {
    return InkWell(
      onTap: () {
        ctrl.text = val.toString();
        onUpdate();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: C.borderSoft),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: C.brand)),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    final items = a.cart.values.toList();
    final total = a.cartTotal;

    // Auto-samakan Uang Tunai dengan Total selama user belum mengubah manual.
    // Update otomatis saat qty item berubah (tablet/hp) asalkan nilai sebelumnya
    // masih sama dengan total lama atau masih 0/kosong.
    if (_metode == 'cash') {
      final prev = int.tryParse(_uang.text) ?? 0;
      if ((_uang.text.isEmpty || prev == 0 || prev == _lastAutoTotal) &&
          _uang.text != total.toString()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _metode != 'cash') return;
          _uang.text = total.toString();
          _uang.selection = TextSelection.collapsed(offset: _uang.text.length);
          setState(() {});
        });
      }
      _lastAutoTotal = total;
    }

    final tunai = int.tryParse(_uang.text) ?? 0;
    final kembali = _metode == 'cash' ? tunai - total : 0;
    final sw = MediaQuery.of(context).size.width;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final showQrisInfo = _metode == 'qris' && a.qrisToken.isNotEmpty;
    final showTransferInfo = _metode == 'transfer' && a.noRekening.isNotEmpty;

    Widget buildContent() {
      final isTab = widget.isTablet;
      return Material(
        color: Colors.white,
        borderRadius: widget.isTablet
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: widget.isTablet
                ? double.infinity
                : MediaQuery.of(context).size.height * 0.88,
            // Mobile bottom-sheet: batasi lebar di layar lebar; tablet sudah di-constrain parent
            maxWidth: widget.isTablet
                ? double.infinity
                : (sw > 640 ? 520.0 : double.infinity),
          ),
          child: Column(children: [
            // ── Header (fixed) ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                color: C.brand,
                borderRadius: widget.isTablet
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(children: [
                const Expanded(
                  child: Text('Keranjang',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                if (!widget.isTablet)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
              ]),
            ),

            // List item, hanya bagian ini yang scroll
            if (items.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Keranjang masih kosong',
                      style: TextStyle(color: C.muted, fontSize: 14)),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: false,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    // Harga satuan efektif (bisa beda kalau ada tier)
                    final unitHarga = c.qty > 0
                        ? (c.subtotal / c.qty).round()
                        : c.harga;
                    final subtitleText = c.qty == 1 && c.tiers.isEmpty
                        ? Formatter.rupiah(c.harga)
                        : '${Formatter.qty(c.qty)} x ${Formatter.rupiah(unitHarga)}';
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(vertical: 2),
                      minVerticalPadding: 2,
                      title: Text(c.nama,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        subtitleText,
                        style: const TextStyle(fontSize: 13, color: C.muted),
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        // Subtotal baris (harga x qty) — selalu tampil
                        Text(
                          Formatter.rupiah(c.subtotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: C.text,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon:
                              const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () => a.decCart(c.produkId),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        GestureDetector(
                          onTap: () => _editQty(context, c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: C.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(Formatter.qty(c.qty),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () {
                            final match = a.produk
                                .where((e) => e.id == c.produkId)
                                .toList();
                            if (match.isNotEmpty) a.addCart(match.first);
                          },
                        ),
                      ]),
                    );
                  },
                ),
              ),

            // ── Payment section (fixed, tidak scroll) ──────────────────
            // Tablet: kompak biar list item lebih banyak terlihat
            // HP: lebih lega & mudah disentuh
            Container(
              padding: EdgeInsets.fromLTRB(
                  12,
                  isTab ? 6 : 10,
                  12,
                  (isTab ? 8 : 12) +
                      (isTab ? 0 : MediaQuery.of(context).padding.bottom)),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: C.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Metode pembayaran
                  Text('Metode Pembayaran',
                      style: TextStyle(
                          fontSize: isTab ? 11 : 13,
                          fontWeight: FontWeight.w600,
                          color: C.muted)),
                  SizedBox(height: isTab ? 4 : 6),
                  Row(
                    children: [
                      Expanded(
                        child: _MetodeBtn(
                          icon: Icons.payments_outlined,
                          label: 'Cash',
                          active: _metode == 'cash',
                          compact: isTab,
                          onTap: () => setState(() {
                            _metode = 'cash';
                            _uang.text = total.toString();
                            _lastAutoTotal = total;
                          }),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _MetodeBtn(
                          icon: Icons.qr_code_rounded,
                          label: 'QRIS',
                          active: _metode == 'qris',
                          compact: isTab,
                          onTap: () => setState(() => _metode = 'qris'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _MetodeBtn(
                          icon: Icons.account_balance_outlined,
                          label: 'Transfer',
                          active: _metode == 'transfer',
                          compact: isTab,
                          onTap: () => setState(() => _metode = 'transfer'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _MetodeBtn(
                          icon: Icons.handshake_outlined,
                          label: 'Hutang',
                          active: _metode == 'hutang',
                          compact: isTab,
                          onTap: () => setState(() => _metode = 'hutang'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isTab ? 6 : 8),

                  // Form nama hutang + saran nama yang masih punya piutang
                  if (_metode == 'hutang') ...[
                    Builder(builder: (context) {
                      final names = <String>{};
                      for (final t in a.transaksi) {
                        if (t.status == 'hutang') {
                          final n = t.namaHutang.trim();
                          if (n.isNotEmpty) names.add(n);
                        }
                      }
                      final sorted = names.toList()
                        ..sort((a, b) =>
                            a.toLowerCase().compareTo(b.toLowerCase()));
                      final q = _namaHutang.text.trim().toLowerCase();
                      final suggestions = q.isEmpty
                          ? sorted
                          : sorted
                              .where((n) => n.toLowerCase().contains(q))
                              .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _namaHutang,
                            textCapitalization: TextCapitalization.words,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Nama yang berhutang',
                              hintText: sorted.isEmpty
                                  ? 'Ketik nama baru'
                                  : 'Pilih dari daftar atau ketik nama baru',
                              prefixIcon:
                                  const Icon(Icons.person_outline_rounded),
                              filled: true,
                              fillColor: C.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: C.borderSoft),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: C.borderSoft),
                              ),
                            ),
                          ),
                          if (suggestions.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 140),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: C.borderSoft),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: suggestions.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final name = suggestions[i];
                                  final total = a.transaksi
                                      .where((t) =>
                                          t.status == 'hutang' &&
                                          t.namaHutang.trim().toLowerCase() ==
                                              name.toLowerCase())
                                      .fold<int>(
                                          0, (s, t) => s + t.totalBelanja);
                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: const Icon(
                                        Icons.person_outline,
                                        size: 20,
                                        color: C.brand),
                                    title: Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    subtitle: Text(
                                      'Piutang ${Formatter.rupiah(total)}',
                                      style: const TextStyle(
                                          fontSize: 11, color: C.muted),
                                    ),
                                    onTap: () {
                                      _namaHutang.text = name;
                                      _namaHutang.selection =
                                          TextSelection.collapsed(
                                              offset: name.length);
                                      setState(() {});
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDBA74)),
                      ),
                      child: const Text(
                        'Stok langsung dipotong. Transaksi belum masuk laporan sampai hutang dilunasi.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Info QRIS
                  if (showQrisInfo) ...[
                    Builder(builder: (context) {
                      final dynamicQris =
                          QrisDynamic.generate(a.qrisToken, a.cartTotal) ??
                              a.qrisToken;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: C.brandLight,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: C.brand.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(children: [
                                const Icon(Icons.qr_code_rounded,
                                    size: 14, color: C.brand),
                                const SizedBox(width: 6),
                                const Text('Scan QRIS untuk Pembayaran',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: C.brand)),
                              ]),
                              const SizedBox(height: 10),
                              Center(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: C.brand.withValues(alpha: 0.3)),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: QrImageView(
                                    data: dynamicQris,
                                    version: QrVersions.auto,
                                    size: 180,
                                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nominal: ${Formatter.rupiah(a.cartTotal)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: C.brand),
                              ),
                            ]),
                      );
                    }),
                    const SizedBox(height: 10),
                  ],

                  // Info Transfer
                  if (showTransferInfo) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.brandLight,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: C.brand.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.account_balance_outlined,
                                  size: 16, color: C.brand),
                              const SizedBox(width: 6),
                              Text(a.bankName.isNotEmpty ? a.bankName : 'Bank',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: C.brand)),
                            ]),
                            const SizedBox(height: 4),
                            Text(a.noRekening,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                            if (a.atasNama.isNotEmpty)
                              Text('a.n. ${a.atasNama}',
                                  style: const TextStyle(
                                      fontSize: 12, color: C.muted)),
                          ]),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Input uang tunai + kembalian (hanya cash)
                  // Subtotal dihapus - sudah ada Total di bawah
                  if (_metode == 'cash') ...[
                    TextField(
                      controller: _uang,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: isTab ? 15 : 17,
                          fontWeight: FontWeight.bold),
                      onChanged: (_) {
                        // User mengubah manual → jangan auto-overwrite lagi
                        _lastAutoTotal = -1;
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Uang Tunai',
                        labelStyle: TextStyle(
                            fontSize: isTab ? 14 : 15,
                            fontWeight: FontWeight.w600,
                            color: C.text2),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: isTab ? 8 : 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: C.brand, width: 2),
                        ),
                        suffixText: 'Rp',
                        suffixStyle: TextStyle(
                            color: C.muted, fontSize: isTab ? 12 : 13),
                      ),
                    ),
                    SizedBox(height: isTab ? 4 : 6),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: isTab ? 6 : 10),
                      decoration: BoxDecoration(
                        color: kembali >= 0 ? C.successSoft : C.dangerSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Text('Kembalian',
                            style: TextStyle(
                                color: kembali >= 0 ? C.success : C.danger,
                                fontWeight: FontWeight.w600,
                                fontSize: isTab ? 12 : 13)),
                        const Spacer(),
                        Text(Formatter.rupiah(kembali < 0 ? 0 : kembali),
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: isTab ? 14 : 16,
                                color: kembali >= 0 ? C.success : C.danger)),
                      ]),
                    ),
                    SizedBox(height: isTab ? 4 : 6),
                  ],

                  // Total + tombol bayar
                  Divider(height: isTab ? 8 : 10),
                  Row(children: [
                    Text('Total',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isTab ? 14 : 16)),
                    const Spacer(),
                    Text(Formatter.rupiah(total),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: isTab ? 16 : 18,
                            color: C.brand)),
                  ]),
                  SizedBox(height: isTab ? 6 : 8),

                  // Hutang: 1 tombol saja. Lainnya: 1 tombol jika Auto Print, 2 jika mati
                  if (_metode == 'hutang' || a.printerAutoPrint)
                    SizedBox(
                      height: isTab ? 40 : 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: C.brand,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(sw >= 1100 ? 14 : 28)),
                        ),
                        onPressed: items.isEmpty ? null : () => _pay(),
                        child: Text(
                          _metode == 'cash'
                              ? 'Bayar Cash'
                              : _metode == 'qris'
                                  ? 'Konfirmasi QRIS'
                                  : _metode == 'hutang'
                                      ? 'Catat Hutang'
                                      : 'Konfirmasi Transfer',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else
                    Row(children: [
                      Expanded(
                        child: SizedBox(
                          height: isTab ? 40 : 46,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side:
                                  const BorderSide(color: C.brand, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      sw >= 1100 ? 14 : 28)),
                            ),
                            onPressed: items.isEmpty
                                ? null
                                : () => _pay(manualPrint: true),
                            icon: const Icon(Icons.print_rounded, size: 18),
                            label: const Text('Print Nota',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: C.brand,
                                    fontSize: 13)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: isTab ? 40 : 46,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: C.brand,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      sw >= 1100 ? 14 : 28)),
                            ),
                            onPressed: items.isEmpty ? null : () => _pay(),
                            child: Text(
                              _metode == 'cash'
                                  ? 'Bayar Cash'
                                  : _metode == 'hutang'
                                      ? 'Catat Hutang'
                                      : 'Bayar',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          ]),
        ),
      );
    }

    if (widget.isTablet) return buildContent();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      // Padding bawah naik saat keyboard muncul
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: buildContent(),
    );
  }
}

class _MetodeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool compact; // true = tablet (horizontal, pendek)
  final VoidCallback onTap;
  const _MetodeBtn(
      {required this.icon,
      required this.label,
      required this.active,
      this.compact = false,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: compact ? 8 : 10,
          horizontal: 4,
        ),
        decoration: BoxDecoration(
          color: active ? C.brand : C.bg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: active ? C.brand : C.border),
        ),
        // Tablet: icon+label horizontal (hemat tinggi)
        // HP: icon di atas, label di bawah (lebih lega disentuh)
        child: compact
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: active ? Colors.white : C.muted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : C.muted)),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: active ? Colors.white : C.muted),
                  const SizedBox(height: 4),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : C.muted)),
                ],
              ),
      ),
    );
  }
}
