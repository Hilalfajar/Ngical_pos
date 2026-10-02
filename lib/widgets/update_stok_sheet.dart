import 'dart:io';
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

/// Halaman / panel Update Stok (tab di menu Produk).
/// PC/Tablet: 2 kolom. HP: list penuh + tombol buka daftar (mirip keranjang kasir).
class UpdateStokPage extends StatefulWidget {
  const UpdateStokPage({super.key});

  @override
  State<UpdateStokPage> createState() => _UpdateStokPageState();
}

class _UpdateStokPageState extends State<UpdateStokPage> {
  final _q = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  final Map<int, double> _pending = {};
  bool _saving = false;

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

  List<Produk> _filter(List<Produk> all) {
    if (_query.isEmpty) return all;
    final s = _query.toLowerCase();
    return all
        .where((p) =>
            p.nama.toLowerCase().contains(s) ||
            (p.barcode?.toLowerCase().contains(s) ?? false))
        .toList();
  }

  void _startScan() {
    if (!_canScanCamera) return;
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
    setState(() {
      _pending[p.id!] = (_pending[p.id!] ?? 0) + delta;
      if (_pending[p.id!]! <= 0) _pending.remove(p.id!);
    });
  }

  void _setQty(int id, double qty) {
    setState(() {
      if (qty <= 0) {
        _pending.remove(id);
      } else {
        _pending[id] = qty;
      }
    });
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
    if (_pending.isEmpty) {
      AppToast.error(context, 'Belum ada item');
      return;
    }
    final a = context.read<App>();
    setState(() => _saving = true);
    final n = await a.tambahStokBatch(Map<int, double>.from(_pending));
    if (!mounted) return;
    setState(() => _saving = false);
    if (n <= 0) {
      AppToast.error(context, 'Gagal menyimpan stok');
      return;
    }
    AppToast.success(context, '$n produk stoknya ditambah', title: 'Berhasil');
    setState(() => _pending.clear());
  }

  List<({Produk p, double qty})> _pendingItems(App a) {
    final out = <({Produk p, double qty})>[];
    for (final e in _pending.entries) {
      final match = a.produk.where((p) => p.id == e.key).toList();
      if (match.isNotEmpty) out.add((p: match.first, qty: e.value));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    final list = _filter(a.produk);
    final sw = MediaQuery.sizeOf(context).width;
    // PC lebar: 2 kolom. HP & tablet: list + bar bawah (hindari layout pecah)
    final useSplit = sw >= 1100;
    final pending = _pendingItems(a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchBar(a),
        if (_scanning && _scanCtrl != null)
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
          child: useSplit
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 55, child: _productList(list)),
                    const VerticalDivider(width: 1, color: C.borderSoft),
                    Expanded(flex: 45, child: _pendingPanel(pending)),
                  ],
                )
              : _phoneBody(list, pending),
        ),
      ],
    );
  }

  Widget _searchBar(App a) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.borderSoft),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: C.muted),
                  const SizedBox(width: 6),
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
                        final filtered = _filter(a.produk);
                        if (filtered.length == 1) {
                          _add(filtered.first);
                          _q.clear();
                          setState(() => _query = '');
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'Cari nama / barcode...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _q.clear();
                        setState(() => _query = '');
                      },
                      child: const Icon(Icons.close, size: 18, color: C.muted),
                    ),
                ],
              ),
            ),
          ),
          if (_canScanCamera) ...[
            const SizedBox(width: 8),
            Material(
              color: _scanning ? C.dangerSoft : C.brandLight,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _scanning ? _stopScan : _startScan,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    _scanning
                        ? Icons.close_rounded
                        : Icons.qr_code_scanner_rounded,
                    color: _scanning ? C.danger : C.brand,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// HP & tablet: list penuh + bar bawah kompak (mirip keranjang kasir)
  Widget _phoneBody(List<Produk> list, List<({Produk p, double qty})> pending) {
    final label = pending.isEmpty
        ? 'Belum ada item'
        : '${pending.length} item · +${Formatter.qty(pending.fold<double>(0, (s, e) => s + e.qty))}';

    // Bottom nav hanya di layar sempit (home.dart: width <= 900)
    final hasBottomNav = MediaQuery.sizeOf(context).width <= 900;
    final bottomGap = hasBottomNav ? 72.0 : 12.0;

    final btnStyle = FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: C.brand,
      disabledBackgroundColor: Colors.white24,
      disabledForegroundColor: Colors.white54,
      minimumSize: const Size(0, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    final outlineStyle = OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white70),
      minimumSize: const Size(0, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _productList(list)),
        Padding(
          padding: EdgeInsets.only(bottom: bottomGap),
          child: Material(
            color: C.brand,
            elevation: 6,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (pending.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _openPendingSheet(pending),
                      style: outlineStyle,
                      child:
                          const Text('Daftar', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving || pending.isEmpty ? null : _submit,
                    style: btnStyle,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: C.brand),
                          )
                        : const Text('Simpan',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openPendingSheet(List<({Produk p, double qty})> pending) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            // sync with parent state
            final a = context.watch<App>();
            final items = _pendingItems(a);
            return Material(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: MediaQuery.sizeOf(ctx).height * 0.55,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: C.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text('Akan ditambah',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                            const Spacer(),
                            Text('${items.length} item',
                                style: const TextStyle(color: C.muted)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: items.isEmpty
                            ? const Center(
                                child: Text('Kosong',
                                    style: TextStyle(color: C.muted)))
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (_, i) {
                                  final it = items[i];
                                  return _pendingTile(it, onChanged: () {
                                    setState(() {});
                                    setModal(() {});
                                  });
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton(
                            onPressed: items.isEmpty || _saving
                                ? null
                                : () async {
                                    Navigator.pop(ctx);
                                    await _submit();
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: C.brand,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Simpan Stok',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _pendingTile(({Produk p, double qty}) it, {VoidCallback? onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                Text(it.p.nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  'Stok ${Formatter.qty(it.p.stok)} → ${Formatter.qty(it.p.stok + it.qty)}',
                  style: const TextStyle(fontSize: 11, color: C.muted),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              _add(it.p, -1);
              onChanged?.call();
            },
            icon: const Icon(Icons.remove_circle_outline, size: 20),
          ),
          GestureDetector(
            onTap: () async {
              await _editQtyDialog(it.p, it.qty);
              onChanged?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(Formatter.qty(it.qty),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              _add(it.p, 1);
              onChanged?.call();
            },
            icon:
                const Icon(Icons.add_circle_outline, size: 20, color: C.brand),
          ),
        ],
      ),
    );
  }

  Widget _productList(List<Produk> list) {
    if (list.isEmpty) {
      return const Center(
          child:
              Text('Produk tidak ditemukan', style: TextStyle(color: C.muted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final p = list[i];
        final addQty = p.id != null ? (_pending[p.id!] ?? 0) : 0.0;
        final low = p.stok <= 0;
        final thin = p.stok > 0 && p.stok <= 5;
        return Material(
          color: addQty > 0
              ? C.brandLight
              : (low ? C.dangerSoft : (thin ? C.warningSoft : Colors.white)),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _add(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: addQty > 0 ? C.brand.withOpacity(0.4) : C.borderSoft,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nama,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          'Stok ${Formatter.qty(p.stok)}'
                          '${p.satuan.isNotEmpty ? ' ${p.satuan}' : ''}'
                          '${p.barcode != null && p.barcode!.isNotEmpty ? ' · ${p.barcode}' : ''}',
                          style: const TextStyle(fontSize: 11, color: C.muted),
                        ),
                      ],
                    ),
                  ),
                  if (addQty > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: C.brand,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('+${Formatter.qty(addQty)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  Icon(Icons.add_circle_outline,
                      color: addQty > 0 ? C.brand : C.muted, size: 22),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pendingPanel(List<({Produk p, double qty})> pending) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Text('Akan ditambah',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const Spacer(),
                Text('${pending.length} item',
                    style: const TextStyle(color: C.muted, fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: pending.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Ketuk produk di daftar\nuntuk menambah qty',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: C.muted, height: 1.4),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: pending.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _pendingTile(pending[i]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _saving || pending.isEmpty ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: C.brand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        pending.isEmpty
                            ? 'Simpan Stok'
                            : 'Simpan Stok (${pending.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
              ),
            ),
          ),
        ],
      ),
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
      _setQty(p.id!, result);
    }
  }
}
