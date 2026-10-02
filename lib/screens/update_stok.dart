import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app.dart';
import '../theme.dart';
import '../utils/formatter.dart';
import '../utils/toast.dart';

/// Menu Update Stok (terpisah): tab Update + History
class UpdateStokMenuPage extends StatefulWidget {
  const UpdateStokMenuPage({super.key});

  @override
  State<UpdateStokMenuPage> createState() => _UpdateStokMenuPageState();
}

class _UpdateStokMenuPageState extends State<UpdateStokMenuPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    final isPc = MediaQuery.sizeOf(context).width >= 1100;

    if (isPc) {
      return Scaffold(
        backgroundColor: C.bg,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPcLeftNav(a),
            Container(width: 1, color: C.borderSoft),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: _tab.index == 0 ? 'Update Stok' : 'History Stok',
                    subtitle: _tab.index == 0
                        ? (a.pendingStok.isEmpty
                            ? 'Tambah stok tanpa edit produk'
                            : '${a.pendingStok.length} item di list')
                        : '${a.stokUpdates.length} riwayat',
                  ),
                  Expanded(
                    child: _tab.index == 0
                        ? const UpdateStokPage()
                        : const _StokHistoryView(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // HP / tablet: header + tab bar atas
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Update Stok',
              subtitle: _tab.index == 0
                  ? (a.pendingStok.isEmpty
                      ? 'Tambah stok tanpa edit produk'
                      : '${a.pendingStok.length} item di list')
                  : '${a.stokUpdates.length} riwayat',
              trailing: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: C.brandLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _tab.index == 0
                      ? Icons.add_box_outlined
                      : Icons.history_rounded,
                  color: C.brand,
                  size: 22,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: C.brand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: C.muted,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Update'),
                    Tab(text: 'History'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _tab.index == 0
                  ? const UpdateStokPage()
                  : const _StokHistoryView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPcLeftNav(App a) {
    Widget item({
      required IconData icon,
      required String label,
      required int id,
      int? badge,
    }) {
      final active = _tab.index == id;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Material(
          color: active ? C.brandLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (_tab.index != id) _tab.animateTo(id);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: active ? C.brand : C.faint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? C.brand : C.text,
                      ),
                    ),
                  ),
                  if (badge != null && badge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: active ? C.brand : C.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badge',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : C.muted,
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

    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: C.brandLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_box_outlined,
                      color: C.brand, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Update Stok',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Text(
              'SECTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: C.muted,
                letterSpacing: 0.6,
              ),
            ),
          ),
          item(
            icon: Icons.add_box_outlined,
            label: 'Update',
            id: 0,
            badge: a.pendingStok.isEmpty ? null : a.pendingStok.length,
          ),
          item(
            icon: Icons.history_rounded,
            label: 'History',
            id: 1,
            badge: a.stokUpdates.isEmpty ? null : a.stokUpdates.length,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Konten update (list + pending) - state di App.pendingStok
class UpdateStokPage extends StatefulWidget {
  const UpdateStokPage({super.key});

  @override
  State<UpdateStokPage> createState() => _UpdateStokPageState();
}

class _UpdateStokPageState extends State<UpdateStokPage> {
  final _q = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  bool _saving = false;
  bool _showOnlyPending = false;

  bool _scanning = false;
  MobileScannerController? _scanCtrl;
  DateTime _lastScan = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _canScanCamera {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _q.dispose();
    _searchFocus.dispose();
    _scanCtrl?.dispose();
    super.dispose();
  }

  List<Produk> _filter(List<Produk> all, Map<int, double> pending) {
    var filtered = all;
    if (_showOnlyPending) {
      filtered = filtered.where((p) => pending.containsKey(p.id)).toList();
    }
    if (_query.isEmpty) return filtered;
    final s = _query.toLowerCase();
    return filtered
        .where((p) =>
            p.nama.toLowerCase().contains(s) ||
            (p.barcode?.toLowerCase().contains(s) ?? false))
        .toList();
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

  void _add(Produk p, [double delta = 1]) {
    if (p.id == null) return;
    final a = context.read<App>();
    final current = a.pendingStok[p.id!] ?? 0.0;
    if (delta < 0 && current <= 0) return;
    a.addPendingStok(p.id!, delta);
  }

  void _onBarcode(String code) {
    final now = DateTime.now();
    if (now.difference(_lastScan) < const Duration(milliseconds: 1000)) {
      return;
    }
    _lastScan = now;
    final a = context.read<App>();
    final matches = a.produk
        .where((p) =>
            (p.barcode ?? '').trim().toLowerCase() == code.trim().toLowerCase())
        .toList();
    if (matches.isEmpty) {
      AppToast.error(context, 'Tidak ditemukan: $code');
      return;
    }
    _add(matches.first);
  }

  Future<void> _submit() async {
    final a = context.read<App>();
    if (a.pendingStok.isEmpty) {
      AppToast.error(context, 'Belum ada item');
      return;
    }
    setState(() => _saving = true);
    final n = await a.simpanPendingStok();
    if (!mounted) return;
    setState(() => _saving = false);
    if (n <= 0) {
      AppToast.error(context, 'Gagal menyimpan stok');
      return;
    }
    AppToast.success(context, '$n produk stoknya ditambah', title: 'Berhasil');
  }

  List<({Produk p, double qty})> _pendingItems(App a) {
    final out = <({Produk p, double qty})>[];
    for (final e in a.pendingStok.entries) {
      final match = a.produk.where((p) => p.id == e.key).toList();
      if (match.isNotEmpty) out.add((p: match.first, qty: e.value));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    final pendingMap = a.pendingStok;
    final list = _filter(a.produk, pendingMap);
    final sw = MediaQuery.sizeOf(context).width;
    final isWide = sw >= 1100;
    final pendingList = _pendingItems(a);

    return ContentWidth(
      maxWidth: 800,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isWide && _scanning && _scanCtrl != null)
                Container(
                  height: 180,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.black,
                  ),
                  child: Stack(children: [
                    MobileScanner(
                      controller: _scanCtrl!,
                      onDetect: (capture) {
                        final bars = capture.barcodes;
                        if (bars.isEmpty) return;
                        final raw = bars.first.rawValue;
                        if (raw != null && raw.isNotEmpty) _onBarcode(raw);
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
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ),
                  ]),
                ),
              _searchBar(a),
              if (isWide && _scanning && _scanCtrl != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 140,
                      child: MobileScanner(
                        controller: _scanCtrl,
                        onDetect: (capture) {
                          final bars = capture.barcodes;
                          if (bars.isEmpty) return;
                          final raw = bars.first.rawValue;
                          if (raw != null && raw.isNotEmpty) _onBarcode(raw);
                        },
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _productList(list, a, isWide),
              ),
            ],
          ),
          if (pendingList.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              bottom: isWide ? 10 : 70,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: C.brand,
                        elevation: 4,
                        shadowColor: C.brand.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Simpan Stok (${pendingList.length} item)',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchBar(App a) {
    final sw = MediaQuery.sizeOf(context).width;
    final isPc = sw >= 1100;

    if (!isPc) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: C.brand.withOpacity(0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: C.brand.withOpacity(0.08),
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
                  focusNode: _searchFocus,
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (v) {
                    final code = v.trim();
                    if (code.isEmpty) return;
                    final exact = a.produk
                        .where((p) =>
                            (p.barcode ?? '').trim().toLowerCase() ==
                            code.toLowerCase())
                        .toList();
                    if (exact.isNotEmpty) {
                      _add(exact.first);
                      _q.clear();
                      setState(() => _query = '');
                      return;
                    }
                    final filtered = _filter(a.produk, a.pendingStok);
                    if (filtered.length == 1) {
                      _add(filtered.first);
                      _q.clear();
                      setState(() => _query = '');
                    }
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
              GestureDetector(
                onTap: () =>
                    setState(() => _showOnlyPending = !_showOnlyPending),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _showOnlyPending ? C.brand : C.brandLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: _showOnlyPending ? Colors.white : C.brand,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _scanning ? _stopScan : _startScan,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    _scanning ? Icons.close : Icons.qr_code_scanner,
                    color: _scanning ? C.danger : C.brand,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // PC Mode: Style Kasir
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.brand.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: C.brand.withOpacity(0.08),
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
              child: const Icon(Icons.search_rounded, color: C.brand, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _q,
                focusNode: _searchFocus,
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (v) {
                  final code = v.trim();
                  if (code.isEmpty) return;
                  final exact = a.produk
                      .where((p) =>
                          (p.barcode ?? '').trim().toLowerCase() ==
                          code.toLowerCase())
                      .toList();
                  if (exact.isNotEmpty) {
                    _add(exact.first);
                    _q.clear();
                    setState(() => _query = '');
                    return;
                  }
                  final filtered = _filter(a.produk, a.pendingStok);
                  if (filtered.length == 1) {
                    _add(filtered.first);
                    _q.clear();
                    setState(() => _query = '');
                  }
                },
                textInputAction: TextInputAction.search,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
            if (_query.isNotEmpty)
              IconButton(
                onPressed: () {
                  _q.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close_rounded, size: 18, color: C.muted),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _showOnlyPending = !_showOnlyPending),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _showOnlyPending
                      ? C.brand
                      : C.brandLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        _showOnlyPending ? C.brand : C.brand.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showOnlyPending
                          ? Icons.check_circle_rounded
                          : Icons.filter_list_rounded,
                      size: 16,
                      color: _showOnlyPending ? Colors.white : C.brand,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pilihan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _showOnlyPending ? Colors.white : C.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productList(List<Produk> list, App a, bool isWide) {
    if (list.isEmpty) {
      return Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_showOnlyPending ? Icons.inventory_2_outlined : Icons.search_off,
              size: 48, color: C.faint),
          const SizedBox(height: 12),
          Text(
              _showOnlyPending
                  ? 'Belum ada item yang dipilih'
                  : 'Produk tidak ditemukan',
              style: const TextStyle(color: C.muted)),
        ],
      ));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final p = list[i];
        final addQty = p.id != null ? (a.pendingStok[p.id!] ?? 0) : 0.0;
        final hasPending = addQty > 0;

        return Material(
          color: hasPending ? C.brandLight : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _add(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasPending
                      ? C.brand.withValues(alpha: 0.4)
                      : C.borderSoft,
                  width: hasPending ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: C.text)),
                        const SizedBox(height: 2),
                        Text(
                          hasPending
                              ? 'Stok ${Formatter.qty(p.stok)} → ${Formatter.qty(p.stok + addQty)}'
                              : 'Stok ${Formatter.qty(p.stok)} ${p.satuan} · ${p.barcode ?? "-"}',
                          style:
                              const TextStyle(fontSize: 10.5, color: C.muted),
                        ),
                      ],
                    ),
                  ),
                  if (hasPending) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _add(p, -1),
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          size: 18, color: C.text2),
                    ),
                    GestureDetector(
                      onTap: () => _editQtyDialog(p, addQty),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: C.borderSoft),
                        ),
                        child: Text(
                          Formatter.qty(addQty),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: C.text),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _add(p, 1),
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          size: 18, color: C.brand),
                    ),
                  ] else
                    IconButton(
                      onPressed: () => _add(p),
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          size: 20, color: C.brand),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editQtyDialog(Produk p, double current) async {
    final ctrl = TextEditingController(text: Formatter.qty(current));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Qty - ${p.nama}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Tambah qty',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            final n = double.tryParse(v.replaceAll(',', '.'));
            Navigator.pop(ctx, n);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final n = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(ctx, n);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && p.id != null) {
      context.read<App>().setPendingStokQty(p.id!, result);
    }
  }
}

class _StokHistoryView extends StatefulWidget {
  const _StokHistoryView();

  @override
  State<_StokHistoryView> createState() => _StokHistoryViewState();
}

class _StokHistoryViewState extends State<_StokHistoryView> {
  StokUpdate? _selected;
  List<StokUpdateItem> _items = [];
  bool _loading = false;

  Future<void> _select(StokUpdate? u) async {
    if (u == null) {
      setState(() {
        _selected = null;
        _items = [];
      });
      return;
    }
    if (_selected?.id == u.id) return;
    setState(() {
      _selected = u;
      _items = [];
      _loading = true;
    });
    final items = await context.read<App>().stokUpdateItemsOf(u.id!);
    if (!mounted) return;
    if (_selected?.id == u.id) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    final list = a.stokUpdates;
    final isPc = MediaQuery.sizeOf(context).width >= 1100;

    // Auto-select first when list changes / empty
    if (list.isNotEmpty) {
      final stillValid =
          _selected != null && list.any((e) => e.id == _selected!.id);
      if (!stillValid) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _select(list.first);
        });
      }
    } else if (_selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _select(null);
      });
    }

    if (list.isEmpty) {
      return const Center(
        child: Text('Belum ada riwayat update stok',
            style: TextStyle(color: C.muted)),
      );
    }

    final listView = _buildList(list, isPc: isPc);

    if (!isPc) {
      final bottom = MediaQuery.sizeOf(context).width <= 900 ? 100.0 : 24.0;
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _historyCard(list[i], selected: false, onTap: () {
              _showDetailSheet(list[i]);
            }),
          ],
        ],
      );
    }

    // PC: list tengah + detail kanan
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: listView),
        Container(width: 1, color: C.borderSoft),
        Expanded(flex: 4, child: _detailPanel()),
      ],
    );
  }

  Widget _buildList(List<StokUpdate> list, {required bool isPc}) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 8, 16, isPc ? 24 : 100),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final u = list[i];
        final selected = isPc && _selected?.id == u.id;
        return _historyCard(
          u,
          selected: selected,
          onTap: () {
            if (isPc) {
              _select(u);
            } else {
              _showDetailSheet(u);
            }
          },
        );
      },
    );
  }

  Widget _historyCard(
    StokUpdate u, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? C.brandLight : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? C.brand.withOpacity(0.45) : C.borderSoft,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? C.brand.withOpacity(0.15) : C.brandLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.inventory_2_outlined, color: C.brand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.kode,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      Formatter.tanggal(u.tanggal),
                      style: const TextStyle(fontSize: 12, color: C.muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${u.totalItem} item',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('+${Formatter.qty(u.totalQty)}',
                      style: const TextStyle(fontSize: 12, color: C.brand)),
                ],
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  color: selected ? C.brand : C.faint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailPanel() {
    if (_selected == null) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(
          child: Text('Pilih riwayat untuk melihat detail',
              style: TextStyle(color: C.muted)),
        ),
      );
    }
    final u = _selected!;
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detail ${u.kode}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        Formatter.tanggal(u.tanggal),
                        style: const TextStyle(fontSize: 13, color: C.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: C.brandLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${Formatter.qty(u.totalQty)}',
                    style: const TextStyle(
                        color: C.brand,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(
                        child: Text('Tidak ada item',
                            style: TextStyle(color: C.muted)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final it = _items[i];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: C.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(it.namaProduk,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${Formatter.qty(it.stokSebelum)} → ${Formatter.qty(it.stokSesudah)}',
                                        style: const TextStyle(
                                            fontSize: 12, color: C.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                Text('+${Formatter.qty(it.qty)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: C.brand,
                                        fontSize: 15)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Text('${u.totalItem} produk',
                    style: const TextStyle(color: C.muted, fontSize: 13)),
                const Spacer(),
                Text('Total +${Formatter.qty(u.totalQty)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: C.brand,
                        fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetailSheet(StokUpdate u) async {
    final items = await context.read<App>().stokUpdateItemsOf(u.id!);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: C.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.kode,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 18)),
                      Text(Formatter.tanggal(u.tanggal),
                          style: const TextStyle(fontSize: 13, color: C.muted)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: C.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.namaProduk,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                    '${Formatter.qty(it.stokSebelum)} → ${Formatter.qty(it.stokSesudah)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: C.muted),
                                  ),
                                ],
                              ),
                            ),
                            Text('+${Formatter.qty(it.qty)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: C.brand,
                                    fontSize: 15)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
