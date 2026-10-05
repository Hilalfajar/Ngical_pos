import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../providers/app.dart';
import '../services/report_service.dart';
import '../services/printer_service.dart';
import '../theme.dart';
import '../utils/formatter.dart';
import '../utils/toast.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});
  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  DateTime? _start;
  DateTime? _end;
  int _tab = 0; // 0=Transaksi, 1=Tren, 2=Hutang
  Transaksi? _selected;
  List<TransaksiItem> _selectedItems = [];
  int? _loadingDetailId;
  /// Group hutang terpilih (key = nama lowercase) + daftar notanya
  String? _selectedHutangKey;
  List<Transaksi> _selectedHutangTrx = [];

  int _hutangFilter = 0; // 0=Semua, 1=Belum Lunas, 2=Lunas
  /// Nama (lowercase) yang di-expand di list hutang ter-group
  final Set<String> _expandedHutang = {};

  bool _scanning = false;
  MobileScannerController? _scanCtrl;
  String? _lastScanned;
  Timer? _scanDebounce;
  static const _scanDelay = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day);
    _end = DateTime(now.year, now.month, now.day, 23, 59, 59);
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
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _playScanBeep() async {
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scanCtrl?.dispose();
    _scanDebounce?.cancel();
    super.dispose();
  }

  void _selectHutangGroup(String key, List<Transaksi> items) {
    setState(() {
      _selectedHutangKey = key;
      _selectedHutangTrx = List<Transaksi>.from(items)
        ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
      _selected = null;
      _selectedItems = [];
      _loadingDetailId = null;
    });
  }

  Future<void> _selectTrx(Transaksi? t) async {
    if (t == null) {
      setState(() {
        _selected = null;
        _selectedItems = [];
        _selectedHutangKey = null;
        _selectedHutangTrx = [];
      });
      return;
    }
    if (_selected?.id == t.id && _selectedHutangKey == null) return;
    setState(() {
      _selected = t;
      _selectedItems = [];
      _loadingDetailId = t.id;
      _selectedHutangKey = null;
      _selectedHutangTrx = [];
    });
    final items = await context.read<App>().itemsOf(t.id!);
    if (!mounted) return;
    if (_selected?.id == t.id) {
      setState(() {
        _selectedItems = items;
        _loadingDetailId = null;
      });
    }
  }

  Future<void> _directPrint(Transaksi trx, List<TransaksiItem> items) async {
    final a = context.read<App>();
    final receiptItems = items
        .map((it) => ReceiptLine(
              nama: it.namaProduk,
              qty: it.jumlah,
              harga: it.hargaSatuan,
              subtotal: it.subtotal,
            ))
        .toList();

    final res = await a.cetakStruk(
      items: receiptItems,
      total: trx.totalBelanja,
      bayar: trx.totalBayar,
      kembalian: trx.kembalian,
      metode: trx.metode,
    );

    if (!res.success && mounted) {
      AppToast.error(context, res.message);
    }
  }

  Future<void> _sharePdf(Transaksi trx, List<TransaksiItem> items) async {
    final a = context.read<App>();
    final receiptItems = items
        .map((it) => ReceiptLine(
              nama: it.namaProduk,
              qty: it.jumlah,
              harga: it.hargaSatuan,
              subtotal: it.subtotal,
            ))
        .toList();

    try {
      final doc = await PrinterService.i.buildReceiptPdf(
        storeName: a.storeName,
        storeAddress: a.storeAddress,
        storePhone: a.storePhone,
        printFooter: a.printerPrintFooter,
        footerText: 'Terima kasih!',
        items: receiptItems,
        total: trx.totalBelanja,
        bayar: trx.totalBayar,
        kembalian: trx.kembalian,
        metode: trx.metode,
        trxNo: '#${trx.noUrut}',
        tanggal: DateTime.fromMillisecondsSinceEpoch(trx.tanggal),
        paperWidthMm: a.printerPaperWidth,
        qrisToken: trx.metode.toLowerCase() == 'qris' ? a.qrisToken : '',
      );

      await Printing.sharePdf(
          bytes: await doc.save(), filename: 'Struk_${trx.noUrut}.pdf');
    } catch (e) {
      if (mounted) AppToast.error(context, 'Gagal membuat PDF: $e');
    }
  }

  void _ensureSelection(List<Transaksi> list) {
    if (list.isEmpty) {
      if (_selected != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _selectTrx(null);
        });
      }
      return;
    }
    final stillValid =
        _selected != null && list.any((t) => t.id == _selected!.id);
    if (!stillValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectTrx(list.first);
      });
    }
  }

  List<Transaksi> _filtered(List<Transaksi> all, {bool isHutangTab = false}) {
    var list = all;
    if (isHutangTab) {
      // Tab Hutang: semua tanggal (lunas & belum), tidak ikut filter "Hari Ini"
      list = list
          .where((t) => t.metode == 'hutang' && t.status != 'batal')
          .toList();
      if (_hutangFilter == 1) {
        list = list.where((t) => t.status == 'hutang').toList();
      } else if (_hutangFilter == 2) {
        list = list.where((t) => t.status == 'selesai').toList();
      }
    } else {
      list = list.where((t) => t.status != 'hutang').toList();
      if (_start != null && _end != null) {
        list = list.where((t) {
          final d = DateTime.fromMillisecondsSinceEpoch(t.tanggal);
          return d.isAfter(_start!.subtract(const Duration(seconds: 1))) &&
              d.isBefore(_end!.add(const Duration(seconds: 1)));
        }).toList();
      }
    }
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((t) {
      final id = '#${t.noUrut}'.contains(q);
      final tgl = Formatter.tanggal(t.tanggal).toLowerCase().contains(q);
      final nominal = Formatter.rupiah(t.totalBelanja).contains(q);
      final nama = t.namaHutang.toLowerCase().contains(q);
      return id || tgl || nominal || nama;
    }).toList();
  }

  void _pilihTanggal() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _start = DateTime(d.year, d.month, d.day);
        _end = DateTime(d.year, d.month, d.day, 23, 59, 59);
      });
    }
  }

  void _pilihPeriode() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _start != null && _end != null
          ? DateTimeRange(start: _start!, end: _end!)
          : null,
    );
    if (r != null) {
      setState(() {
        _start = DateTime(r.start.year, r.start.month, r.start.day);
        _end = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59);
      });
    }
  }

  String get _dateRangeText {
    if (_start == null || _end == null) return 'Semua Waktu';
    final s = DateFormat('dd MMM yyyy').format(_start!);
    final e = DateFormat('dd MMM yyyy').format(_end!);
    if (s == e) {
      final today = DateTime.now();
      if (_start!.day == today.day &&
          _start!.month == today.month &&
          _start!.year == today.year) {
        return 'Hari Ini';
      }
      return s;
    }
    return '$s - $e';
  }

  Future<void> _showDetail(BuildContext context, Transaksi t) async {
    final a = context.read<App>();
    final items = await a.itemsOf(t.id!);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetailSheet(trx: t, items: items),
    );
  }

  Future<void> _konfirmasiBatal(BuildContext context, Transaksi t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan Transaksi?'),
        content: Text(
          'Transaksi #${t.noUrut} sebesar ${Formatter.rupiah(t.totalBelanja)} akan dibatalkan '
          'dan stok produk akan dikembalikan.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<App>().cancelTransaksi(t.id!);
      if (context.mounted) {
        AppToast.success(context, 'Stok produk sudah dikembalikan',
            title: 'Transaksi Dibatalkan');
      }
    }
  }

  Future<void> _editTransaksi(BuildContext context, Transaksi t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Transaksi?'),
        content: const Text(
          'Item transaksi ini akan dimuat ke keranjang kasir. '
          'Anda bisa mengubah item lalu bayar ulang.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final a = context.read<App>();
      await a.editTransaksi(t.id!);
      a.setTab('POS');
      if (context.mounted) {
        AppToast.info(context, 'Ubah item lalu tekan bayar ulang',
            title: 'Item Dimuat ke Keranjang');
      }
    }
  }

  Future<void> _export(BuildContext context, {required bool asPdf}) async {
    final a = context.read<App>();
    final list = _filtered(a.transaksi);
    if (list.isEmpty) {
      AppToast.info(context, 'Tidak ada data transaksi untuk diekspor');
      return;
    }
    try {
      AppToast.info(
          context, asPdf ? 'Menyiapkan PDF...' : 'Menyiapkan Excel...');
      final file = asPdf
          ? await ReportService.i.generatePdf(
              storeName: a.storeName.isEmpty ? 'Ngical' : a.storeName,
              transactions: list,
              dateRange: _dateRangeText,
            )
          : await ReportService.i.generateExcel(
              storeName: a.storeName.isEmpty ? 'Ngical' : a.storeName,
              transactions: list,
              dateRange: _dateRangeText,
            );
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Transaksi Ngical',
      );
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, 'Gagal ekspor: $e');
      }
    }
  }

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: C.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text('Ekspor Laporan',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Periode: $_dateRangeText',
                    style: const TextStyle(color: C.muted, fontSize: 12)),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded,
                        color: Color(0xFFDC2626)),
                  ),
                  title: const Text('Ekspor PDF',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('File .pdf siap dibagikan'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _export(context, asPdf: true);
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.table_chart_rounded,
                        color: Color(0xFF16A34A)),
                  ),
                  title: const Text('Ekspor Excel',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('File .xlsx siap dibagikan'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _export(context, asPdf: false);
                  },
                ),
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
    final filtered = _filtered(a.transaksi);
    final hutangList = _filtered(a.transaksi, isHutangTab: true);

    // Hitung total piutang (hanya yang belum lunas, semua tanggal)
    final allHutangBelumLunas =
        a.transaksi.where((t) => t.status == 'hutang').toList();
    final totalHutang =
        allHutangBelumLunas.fold(0, (s, t) => s + t.totalBelanja);
    final orangHutang = allHutangBelumLunas
        .map((t) => t.namaHutang.trim().toLowerCase())
        .where((n) => n.isNotEmpty)
        .toSet()
        .length;

    // Calculate summary for filtered data
    final trxSelesai = filtered.where((t) => t.status == 'selesai').toList();
    final totalPendapatan = trxSelesai.fold(0, (s, t) => s + t.totalBelanja);
    final trxIds = trxSelesai.map((t) => t.id).toSet();
    final items = a.allItems.where((it) => trxIds.contains(it.transaksiId));
    final totalModal =
        items.fold(0, (s, i) => s + (i.hargaModal * i.jumlah).round());
    final pendapatanBersih = totalPendapatan - totalModal;

    final isPc = MediaQuery.sizeOf(context).width >= 1100;

    // Auto-select first item for master-detail
    if (_tab == 0) {
      _ensureSelection(filtered);
    } else if (_tab == 2) {
      _ensureSelection(hutangList);
    }

    if (isPc) {
      return Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── LEFT: vertical section menu ──
              _buildPcLeftNav(hutangList.length),
              Container(width: 1, color: C.borderSoft),
              // ── MIDDLE + RIGHT ──
              Expanded(
                child: _tab == 1
                    ? Column(
                        children: [
                          _buildPcHeader(
                            subtitle: 'Analisis tren penjualan',
                            trailingCount: null,
                          ),
                          Expanded(
                            child: _TrenView(
                              transaksi: a.transaksi,
                              allItems: a.allItems,
                              produk: a.produk,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // MIDDLE: list
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildPcHeader(
                                  subtitle: _tab == 0
                                      ? (filtered.isEmpty
                                          ? 'Belum ada transaksi'
                                          : '${filtered.length} transaksi')
                                      : (hutangList.isEmpty
                                          ? 'Tidak ada data hutang'
                                          : '${hutangList.length} data ditemukan'),
                                  trailingCount: _tab == 0
                                      ? filtered.length
                                      : hutangList.length,
                                  isHutang: _tab == 2,
                                ),
                                if (_tab == 0) ...[
                                  _buildSummaryBar(totalPendapatan, totalModal,
                                      pendapatanBersih, filtered.length),
                                  _buildDateFilter(),
                                  _buildSearchBar(),
                                ] else if (_tab == 2) ...[
                                  _buildHutangSummary(
                                      totalHutang, orangHutang),
                                  _buildDateFilter(),
                                  _buildSearchBar(),
                                  _buildHutangFilterChips(),
                                ],
                                Expanded(
                                  child: _tab == 0
                                      ? _buildTrxList(filtered, isPc: true)
                                      : _buildHutangList(hutangList,
                                          isPc: true),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, color: C.borderSoft),
                          // RIGHT: detail panel
                          SizedBox(
                            width: 380,
                            child: _buildDetailPanel(),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    }

    // ── MOBILE layout (tetap seperti sebelumnya) ──
    String subtitle;
    if (_tab == 0) {
      subtitle = filtered.isEmpty
          ? 'Belum ada transaksi'
          : '${filtered.length} transaksi';
    } else if (_tab == 1) {
      subtitle = 'Analisis tren penjualan';
    } else {
      subtitle = hutangList.isEmpty
          ? 'Tidak ada hutang aktif'
          : '${hutangList.length} hutang aktif';
    }

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 900,
          child: Column(children: [
            PageHeader(
              title: 'Laporan',
              subtitle: subtitle,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Ekspor',
                    onPressed: () => _showExportSheet(context),
                    icon: const Icon(Icons.ios_share_rounded, color: C.brand),
                  ),
                  if (_tab == 0 && filtered.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: C.brandLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${filtered.length}',
                          style: const TextStyle(
                              color: C.brand,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  if (_tab == 2 && hutangList.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${hutangList.length}',
                          style: const TextStyle(
                              color: Color(0xFFC2410C),
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                ],
              ),
            ),
            if (_scanning && _scanCtrl != null)
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
                      final barcode = capture.barcodes.firstOrNull?.rawValue;
                      if (barcode == null || barcode.isEmpty) return;

                      if (_lastScanned == barcode) return;
                      _lastScanned = barcode;
                      _scanDebounce?.cancel();
                      _scanDebounce = Timer(_scanDelay, () {
                        _lastScanned = null;
                      });

                      _playScanBeep();
                      setState(() {
                        _searchCtrl.text = barcode;
                        _query = barcode;
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
                        'Arahkan ke barcode nota',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  _LapTab(
                    label: 'Transaksi',
                    active: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  _LapTab(
                    label: 'Tren',
                    active: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  _LapTab(
                    label: 'Hutang',
                    active: _tab == 2,
                    onTap: () => setState(() => _tab = 2),
                    badge: hutangList.isEmpty ? null : hutangList.length,
                  ),
                ]),
              ),
            ),
            if (_tab == 1)
              Expanded(
                child: _TrenView(
                  transaksi: a.transaksi,
                  allItems: a.allItems,
                  produk: a.produk,
                ),
              )
            else if (_tab == 2)
              Expanded(
                child: Column(
                  children: [
                    _buildHutangSummary(
                        totalHutang, orangHutang),
                    _buildDateFilter(),
                    _buildSearchBar(),
                    _buildHutangFilterChips(),
                    Expanded(
                      child: _buildHutangList(hutangList, isPc: false),
                    ),
                  ],
                ),
              )
            else ...[
              _buildSummaryBar(totalPendapatan, totalModal, pendapatanBersih,
                  filtered.length),
              _buildDateFilter(),
              _buildSearchBar(),
              Expanded(child: _buildTrxList(filtered, isPc: false)),
            ],
          ]),
        ),
      ),
    );
  }

  // ── PC left vertical nav ──
  Widget _buildPcLeftNav(int hutangCount) {
    Widget item({
      required IconData icon,
      required String label,
      required int id,
      int? badge,
    }) {
      final active = _tab == id;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Material(
          color: active ? C.brandLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              _tab = id;
              _selected = null;
              _selectedItems = [];
            }),
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
                        color: active ? C.brand : const Color(0xFFFDBA74),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badge',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              active ? Colors.white : const Color(0xFF9A3412),
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
                  child: const Icon(Icons.bar_chart_rounded,
                      color: C.brand, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Laporan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: C.text,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Text(
              'SECTIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: C.muted,
                letterSpacing: 0.8,
              ),
            ),
          ),
          item(
            icon: Icons.receipt_long_rounded,
            label: 'Transaksi',
            id: 0,
          ),
          item(
            icon: Icons.trending_up_rounded,
            label: 'Tren',
            id: 1,
          ),
          item(
            icon: Icons.handshake_outlined,
            label: 'Hutang',
            id: 2,
            badge: hutangCount,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _showExportSheet(context),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Ekspor'),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.brand,
                side: BorderSide(color: C.brand.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPcHeader({
    required String subtitle,
    int? trailingCount,
    bool isHutang = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tab == 0
                      ? 'Transaksi'
                      : _tab == 1
                          ? 'Tren'
                          : 'Hutang',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: C.text,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 13, color: C.muted)),
              ],
            ),
          ),
          if (trailingCount != null && trailingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isHutang ? const Color(0xFFFFEDD5) : C.brandLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$trailingCount',
                style: TextStyle(
                  color: isHutang ? const Color(0xFFC2410C) : C.brand,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(int pendapatan, int modal, int bersih, int count) {
    // HP & PC: kartu ungu, Bersih besar, Omzet + Modal + jumlah transaksi
    return _summaryHp(pendapatan, modal, bersih, count);
  }

  /// HP: kartu ungu seperti dashboard - Bersih besar, Omzet + jumlah transaksi
  Widget _summaryHp(int pendapatan, int modal, int bersih, int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: C.brand,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: C.brand.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keuntungan Bersih',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Formatter.rupiah(bersih),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Omzet',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(Formatter.rupiah(pendapatan),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modal',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(Formatter.rupiah(modal),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Transaksi',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHutangSummary(int total, int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEA580C),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Piutang',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12)),
                const SizedBox(height: 4),
                Text(Formatter.rupiah(total),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Text('$count orang',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildHutangFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [
          _HutangStatusChip(
            label: 'Semua',
            active: _hutangFilter == 0,
            onTap: () => setState(() => _hutangFilter = 0),
          ),
          const SizedBox(width: 8),
          _HutangStatusChip(
            label: 'Belum Lunas',
            active: _hutangFilter == 1,
            onTap: () => setState(() => _hutangFilter = 1),
          ),
          const SizedBox(width: 8),
          _HutangStatusChip(
            label: 'Lunas',
            active: _hutangFilter == 2,
            onTap: () => setState(() => _hutangFilter = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.borderSoft),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 16, color: C.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _dateRangeText,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_start != null)
                    GestureDetector(
                      onTap: () => setState(() {
                        _start = null;
                        _end = null;
                      }),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: C.muted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _pilihTanggal,
            icon: const Icon(Icons.event, color: C.brand),
            tooltip: 'Pilih Tanggal',
          ),
          IconButton(
            onPressed: _pilihPeriode,
            icon: const Icon(Icons.date_range, color: C.brand),
            tooltip: 'Pilih Periode',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isLaptop = MediaQuery.sizeOf(context).width >= 1100;
    // HP / Tablet / PC: Style Kasir
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        height: 48,
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
              child: const Icon(Icons.search_rounded, color: C.brand, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  hintText: 'Cari ID nota, tanggal, atau scan...',
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
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
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
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTrxList(List<Transaksi> list, {required bool isPc}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: C.faint),
            const SizedBox(height: 12),
            Text(
              _query.isNotEmpty
                  ? 'Transaksi tidak ditemukan'
                  : 'Belum ada transaksi',
              style: const TextStyle(color: C.muted),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20, 0, 20, isPc ? 24 : 120),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t = list[i];
        final isBatal = t.status == 'batal';
        final selected = isPc && _selected?.id == t.id;
        final items =
            context.read<App>().allItems.where((it) => it.transaksiId == t.id);
        final profit = items.fold(0,
            (s, it) => s + it.subtotal - (it.hargaModal * it.jumlah).round());
        return _TrxCard(
          trx: t,
          isBatal: isBatal,
          selected: selected,
          profit: profit,
          onTap: () {
            if (isPc) {
              _selectTrx(t);
            } else {
              _showDetail(context, t);
            }
          },
          onEdit: isBatal ? null : () => _editTransaksi(context, t),
          onBatal: isBatal ? null : () => _konfirmasiBatal(context, t),
        );
      },
    );
  }

  Widget _buildHutangList(List<Transaksi> list, {required bool isPc}) {
    if (list.isEmpty) {
      return const Center(
        child: Text('Data tidak ditemukan', style: TextStyle(color: C.muted)),
      );
    }

    final groups = <String, List<Transaksi>>{};
    for (final t in list) {
      final key = t.namaHutang.trim().isEmpty
          ? '(tanpa nama)'
          : t.namaHutang.trim().toLowerCase();
      groups.putIfAbsent(key, () => []).add(t);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == '(tanpa nama)') return 1;
        if (b == '(tanpa nama)') return -1;
        return a.compareTo(b);
      });

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20, 0, 20, isPc ? 24 : 120),
      itemCount: keys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final key = keys[i];
        final items = groups[key]!;
        final displayName = key == '(tanpa nama)'
            ? 'Tanpa nama'
            : (items
                .map((t) => t.namaHutang.trim())
                .firstWhere((n) => n.isNotEmpty, orElse: () => key));
        final total = items.fold(0, (s, t) => s + t.totalBelanja);
        final adaPiutang = items.any((t) => t.status == 'hutang');
        final allLunas = items.every((t) => t.status == 'selesai');
        final expanded = _expandedHutang.contains(key);
        final notaCount = items.length;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.borderSoft),
            ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      if (expanded) {
                        _expandedHutang.remove(key);
                      } else {
                        _expandedHutang.add(key);
                      }
                    });
                    if (isPc) {
                      _selectHutangGroup(key, items);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: allLunas
                                ? C.successSoft
                                : const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            allLunas
                                ? Icons.check_circle_outline
                                : Icons.person_outline,
                            color: allLunas
                                ? C.success
                                : const Color(0xFFEA580C),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: C.text,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: allLunas
                                          ? C.successSoft
                                          : C.warningSoft,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      allLunas
                                          ? 'LUNAS'
                                          : (adaPiutang ? 'PIUTANG' : 'LUNAS'),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: allLunas
                                            ? C.success
                                            : C.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$notaCount nota',
                                style: const TextStyle(
                                    color: C.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Formatter.rupiah(total),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: allLunas
                                ? C.text
                                : const Color(0xFFEA580C),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          expanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: C.muted,
                        ),
                      ],
                    ),
                  ),
                ),
                if (expanded) ...[
                  const Divider(height: 1),
                  ...items.map((t) {
                    final isLunas = t.status == 'selesai';
                    final selected = isPc && _selected?.id == t.id;
                    return InkWell(
                      onTap: () {
                        if (isPc) {
                          _selectTrx(t);
                        } else {
                          _showDetail(context, t);
                        }
                      },
                      child: Container(
                        color: selected
                            ? C.brandLight
                            : Colors.transparent,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '#${t.noUrut} · ${Formatter.tanggal(t.tanggal)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: C.text,
                                    ),
                                  ),
                                  Text(
                                    isLunas ? 'Lunas' : 'Belum lunas',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isLunas
                                          ? C.success
                                          : C.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Formatter.rupiah(t.totalBelanja),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            if (!isLunas) ...[
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: C.brand,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          isPc ? 10 : 28)),
                                ),
                                onPressed: () => _confirmLunas(t),
                                child: const Text('Lunas'),
                              ),
                              const SizedBox(width: 4),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: C.danger,
                                  side: const BorderSide(
                                      color: C.danger, width: 1.5),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          isPc ? 10 : 28)),
                                ),
                                onPressed: () =>
                                    _konfirmasiBatalHutang(t),
                                child: const Text('Batalkan'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmLunas(Transaksi t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Lunasi Hutang?'),
        content: Text(
          'Hutang ${t.namaHutang} sebesar ${Formatter.rupiah(t.totalBelanja)} '
          'akan ditandai lunas dan masuk ke laporan transaksi.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Lunas'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<App>().lunasHutang(t.id!);
      if (mounted) {
        AppToast.success(
            context, 'Hutang ${t.namaHutang} sudah lunas & masuk laporan',
            title: 'Berhasil');
      }
    }
  }

  
  /// Batalkan hutang yang salah input / pelanggan tidak jadi beli.
  /// Status → batal, stok dikembalikan, hilang dari daftar piutang.
  Future<void> _konfirmasiBatalHutang(Transaksi t) async {
    if (t.id == null || t.status != 'hutang') return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan Hutang?'),
        content: Text(
          'Hutang ${t.namaHutang.isEmpty ? "(tanpa nama)" : t.namaHutang} '
          'sebesar ${Formatter.rupiah(t.totalBelanja)} akan dibatalkan.\n\n'
          '• Stok produk dikembalikan\n'
          '• Dihapus dari daftar piutang\n'
          '• Tidak masuk laporan penjualan',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tidak')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<App>().cancelTransaksi(t.id!);
      if (mounted) {
        setState(() {
          if (_selected?.id == t.id) {
            _selected = null;
            _selectedItems = [];
          }
        });
        AppToast.success(
          context,
          'Stok sudah dikembalikan, hutang dihapus dari piutang',
          title: 'Hutang Dibatalkan',
        );
      }
    }
  }

  /// Detail gabungan semua nota hutang satu nama, dipisah per tanggal/nota.
  Widget _buildHutangGroupDetail() {
    final items = _selectedHutangTrx;
    final displayName = _selectedHutangKey == '(tanpa nama)'
        ? 'Tanpa nama'
        : (items
            .map((t) => t.namaHutang.trim())
            .firstWhere((n) => n.isNotEmpty,
                orElse: () => _selectedHutangKey!));
    final total = items.fold(0, (s, t) => s + t.totalBelanja);
    final app = context.watch<App>();

    final byDate = <String, List<Transaksi>>{};
    for (final t in items) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.tanggal);
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(key, () => []).add(t);
    }
    final dateKeys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: C.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${items.length} nota · Total ${Formatter.rupiah(total)}',
                  style: const TextStyle(color: C.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Divider(),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: dateKeys.length,
              itemBuilder: (_, di) {
                final dk = dateKeys[di];
                final dayTrx = byDate[dk]!;
                final sample = dayTrx.first.tanggal;
                final d = DateTime.fromMillisecondsSinceEpoch(sample);
                final tglStr = DateFormat('dd MMM yyyy').format(d);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding:
                          EdgeInsets.only(top: di == 0 ? 0 : 16, bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: C.border)),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              tglStr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: C.brand,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: C.border)),
                        ],
                      ),
                    ),
                    ...dayTrx.map((t) {
                      final trxItems = app.allItems
                          .where((it) => it.transaksiId == t.id)
                          .toList();
                      final isLunas = t.status == 'selesai';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: C.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.borderSoft),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Nota #${t.noUrut}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  Formatter.tanggal(t.tanggal),
                                  style: const TextStyle(
                                      fontSize: 11, color: C.muted),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isLunas
                                        ? C.successSoft
                                        : C.warningSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isLunas ? 'LUNAS' : 'PIUTANG',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isLunas ? C.success : C.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (trxItems.isEmpty)
                              const Text('Item tidak tersedia',
                                  style: TextStyle(
                                      fontSize: 12, color: C.muted))
                            else
                              ...trxItems.map((it) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(it.namaProduk,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13)),
                                              Text(
                                                '${it.jumlah} x ${Formatter.rupiah(it.hargaSatuan)}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: C.muted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                            Formatter.rupiah(it.subtotal),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  )),
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Text(
                                  'Subtotal nota',
                                  style: TextStyle(
                                      fontSize: 12, color: C.muted),
                                ),
                                const Spacer(),
                                Text(
                                  Formatter.rupiah(t.totalBelanja),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: C.brand,
                                  ),
                                ),
                              ],
                            ),
                            if (!isLunas) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: C.brand,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      minimumSize: const Size(0, 48),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => _confirmLunas(t),
                                    child: const Text('Lunas'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: C.danger,
                                      side: const BorderSide(
                                          color: C.danger, width: 1.5),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      minimumSize: const Size(0, 48),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    onPressed: () =>
                                        _konfirmasiBatalHutang(t),
                                    child: const Text('Batalkan'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel() {
    // Detail gabungan hutang per nama (multi-nota, dipisah per tanggal)
    if (_selectedHutangKey != null && _selectedHutangTrx.isNotEmpty) {
      return _buildHutangGroupDetail();
    }

    if (_selected == null) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: C.faint),
              SizedBox(height: 12),
              Text('Pilih transaksi', style: TextStyle(color: C.muted)),
            ],
          ),
        ),
      );
    }

    final trx = _selected!;
    final isBatal = trx.status == 'batal';
    final loading = _loadingDetailId == trx.id;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail #${trx.noUrut}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: C.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            Formatter.tanggal(trx.tanggal),
                            style:
                                const TextStyle(color: C.muted, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBatal ? C.dangerSoft : C.brandLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isBatal ? 'BATAL' : trx.metode.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isBatal ? C.danger : C.brand,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _directPrint(trx, _selectedItems),
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.brand,
                    side: const BorderSide(color: C.brand),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _sharePdf(trx, _selectedItems),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('PDF', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.success,
                    side: const BorderSide(color: C.success),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          if (trx.status == 'hutang' && trx.namaHutang.isNotEmpty)
            Builder(builder: (context) {
              final isPc = MediaQuery.sizeOf(context).width >= 1100;

              // Tablet/HP: tombol teks ditebalkan, disusun vertikal.
              // PC: tombol icon di samping nama, sama seperti list transaksi.
              Widget teksLunas() => FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: C.brand,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      minimumSize: const Size(0, 48),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _confirmLunas(trx),
                    child: const Text('Lunas'),
                  );
              Widget teksBatalkan() => OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.danger,
                      side: const BorderSide(color: C.danger, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      minimumSize: const Size(0, 48),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _konfirmasiBatalHutang(trx),
                    child: const Text('Batalkan'),
                  );

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isPc
                      // PC: nama + tombol icon dalam satu baris (ringkas).
                      ? Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 20, color: Color(0xFFEA580C)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                trx.namaHutang,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Color(0xFF9A3412),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Lunas',
                              onPressed: () => _confirmLunas(trx),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                  minWidth: 44, minHeight: 44),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                backgroundColor: C.brand,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.check_rounded, size: 22),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Batalkan',
                              onPressed: () => _konfirmasiBatalHutang(trx),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                  minWidth: 44, minHeight: 44),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                foregroundColor: C.danger,
                                side: const BorderSide(
                                    color: C.danger, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.cancel_outlined, size: 22),
                            ),
                          ],
                        )
                      // Tablet/HP: nama di atas, tombol vertikal di bawahnya.
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline,
                                    size: 20, color: Color(0xFFEA580C)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    trx.namaHutang,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF9A3412),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            teksLunas(),
                            const SizedBox(height: 8),
                            teksBatalkan(),
                          ],
                        ),
                ),
              );
            }),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Divider(),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      ..._selectedItems.map((it) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(it.namaProduk,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: C.text)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${it.jumlah} x ${Formatter.rupiah(it.hargaSatuan)}',
                                        style: const TextStyle(
                                            color: C.muted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(Formatter.rupiah(it.subtotal),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: C.text)),
                              ],
                            ),
                          )),
                      const Divider(height: 24),
                      _Row('Total', Formatter.rupiah(trx.totalBelanja),
                          bold: true),
                      const SizedBox(height: 4),
                      _Row('Dibayar', Formatter.rupiah(trx.totalBayar)),
                      _Row('Kembalian', Formatter.rupiah(trx.kembalian)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

//  Transaction Card

class _TrxCard extends StatelessWidget {
  final Transaksi trx;
  final bool isBatal;
  final bool selected;
  final int profit;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onBatal;

  const _TrxCard({
    required this.trx,
    required this.isBatal,
    this.selected = false,
    this.profit = 0,
    required this.onTap,
    this.onEdit,
    this.onBatal,
  });

  @override
  Widget build(BuildContext context) {
    final isPc = MediaQuery.sizeOf(context).width >= 1100;
    if (isPc) {
      return Material(
        color:
            isBatal ? C.dangerSoft : (selected ? C.brandLight : Colors.white),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBatal
                    ? C.danger.withValues(alpha: 0.3)
                    : (selected
                        ? C.brand.withValues(alpha: 0.45)
                        : C.borderSoft),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text('#${trx.noUrut}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    isBatal ? 'BATAL' : trx.metode.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isBatal ? C.danger : C.brand,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(Formatter.tanggal(trx.tanggal),
                      style: const TextStyle(color: C.muted, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
                // Total + aksi selalu rata kanan (tidak pakai Flexible agar tidak mengambang di tengah)
                Text(
                  Formatter.rupiah(trx.totalBelanja),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isBatal ? C.danger : C.text,
                  ),
                ),
                if (!isBatal) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: C.brand),
                  ),
                  IconButton(
                    tooltip: 'Batal',
                    onPressed: onBatal,
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.cancel_outlined,
                        size: 18, color: C.danger),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: isBatal ? C.dangerSoft : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isBatal
                    ? C.danger.withValues(alpha: 0.3)
                    : C.brand.withValues(alpha: 0.35),
                width: isBatal ? 1.0 : 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isBatal
                        ? C.danger.withValues(alpha: 0.12)
                        : C.brandLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isBatal ? Icons.cancel_outlined : Icons.receipt_rounded,
                    color: isBatal ? C.danger : C.brand,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('#${trx.noUrut}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: C.text)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isBatal
                                ? C.danger.withValues(alpha: 0.12)
                                : C.brandLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isBatal ? 'Batal' : trx.metode.toUpperCase(),
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isBatal ? C.danger : C.brand),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text(Formatter.tanggal(trx.tanggal),
                          style: const TextStyle(color: C.muted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(Formatter.rupiah(trx.totalBelanja),
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isBatal ? C.danger : C.text)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.trending_up_rounded,
                            size: 12, color: C.faint),
                        const SizedBox(width: 3),
                        Text(Formatter.rupiah(profit),
                            style:
                                const TextStyle(color: C.faint, fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
                if (!isBatal) ...[
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 40,
                        child: OutlinedButton(
                          onPressed: onEdit,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: C.brand,
                            side: const BorderSide(color: C.brand, width: 1.5),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('EDIT',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 90,
                        height: 40,
                        child: OutlinedButton(
                          onPressed: onBatal,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: C.danger,
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('BATAL',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: C.brand.withValues(alpha: 0.5)),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

//  Detail Sheet

class _DetailSheet extends StatelessWidget {
  final Transaksi trx;
  final List<TransaksiItem> items;
  const _DetailSheet({required this.trx, required this.items});

  @override
  Widget build(BuildContext context) {
    final isBatal = trx.status == 'batal';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: C.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detail #${trx.noUrut}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: C.text)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text(Formatter.tanggal(trx.tanggal),
                        style: const TextStyle(color: C.muted, fontSize: 12)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isBatal ? C.dangerSoft : C.brandLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isBatal ? 'BATAL' : trx.metode.toUpperCase(),
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isBatal ? C.danger : C.brand),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _printStruk(context),
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Print', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.brand,
                side: const BorderSide(color: C.brand),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _sharePdf(context),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: const Text('PDF', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.success,
                side: const BorderSide(color: C.success),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: C.surface, borderRadius: BorderRadius.circular(10)),
                child:
                    const Icon(Icons.close_rounded, size: 16, color: C.muted),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(children: [
                ...items.map((it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.namaProduk,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: C.text)),
                              const SizedBox(height: 2),
                              Text(
                                '${it.jumlah} x ${Formatter.rupiah(it.hargaSatuan)}',
                                style: const TextStyle(
                                    color: C.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(Formatter.rupiah(it.subtotal),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: C.text)),
                      ]),
                    )),
                const Divider(height: 24),
                _Row('Total', Formatter.rupiah(trx.totalBelanja), bold: true),
                const SizedBox(height: 4),
                _Row('Dibayar', Formatter.rupiah(trx.totalBayar)),
                _Row('Kembalian', Formatter.rupiah(trx.kembalian)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _printStruk(BuildContext context) async {
    final a = context.read<App>();
    final receiptItems = items
        .map((it) => ReceiptLine(
              nama: it.namaProduk,
              qty: it.jumlah,
              harga: it.hargaSatuan,
              subtotal: it.subtotal,
            ))
        .toList();

    final res = await a.cetakStruk(
      items: receiptItems,
      total: trx.totalBelanja,
      bayar: trx.totalBayar,
      kembalian: trx.kembalian,
      metode: trx.metode,
    );

    if (!res.success) {
      AppToast.error(context, res.message);
    }
  }

  void _sharePdf(BuildContext context) async {
    final a = context.read<App>();
    final receiptItems = items
        .map((it) => ReceiptLine(
              nama: it.namaProduk,
              qty: it.jumlah,
              harga: it.hargaSatuan,
              subtotal: it.subtotal,
            ))
        .toList();

    try {
      final doc = await PrinterService.i.buildReceiptPdf(
        storeName: a.storeName,
        storeAddress: a.storeAddress,
        storePhone: a.storePhone,
        printFooter: a.printerPrintFooter,
        footerText: 'Terima kasih!',
        items: receiptItems,
        total: trx.totalBelanja,
        bayar: trx.totalBayar,
        kembalian: trx.kembalian,
        metode: trx.metode,
        trxNo: '#${trx.noUrut}',
        tanggal: DateTime.fromMillisecondsSinceEpoch(trx.tanggal),
        paperWidthMm: a.printerPaperWidth,
        qrisToken: trx.metode.toLowerCase() == 'qris' ? a.qrisToken : '',
      );

      await Printing.sharePdf(
          bytes: await doc.save(), filename: 'Struk_${trx.noUrut}.pdf');
    } catch (e) {
      AppToast.error(context, 'Gagal membuat PDF: $e');
    }
  }
}

class _Row extends StatelessWidget {
  final String l;
  final String v;
  final bool bold;
  const _Row(this.l, this.v, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(l,
              style: TextStyle(
                  color: C.text2,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          const Spacer(),
          Text(v,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  fontSize: bold ? 15 : 13,
                  color: bold ? C.brand : C.text2)),
        ]),
      );
}

//  Tab button

class _LapTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? badge;
  const _LapTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? C.brand : C.muted,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: active ? C.brand : const Color(0xFFFDBA74),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : const Color(0xFF9A3412),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

//  Dashboard / Tren View

class _TrenView extends StatefulWidget {
  final List<Transaksi> transaksi;
  final List<TransaksiItem> allItems;
  final List<Produk> produk;
  const _TrenView({
    required this.transaksi,
    required this.allItems,
    required this.produk,
  });

  @override
  State<_TrenView> createState() => _TrenViewState();
}

class _TrenViewState extends State<_TrenView> {
  // 0=7 Hari, 1=30 Hari, 2=Hari Ini
  int _periode = 0;

  List<Transaksi> get _selesai =>
      widget.transaksi.where((t) => t.status == 'selesai').toList();

  DateTime get _now => DateTime.now();
  DateTime get _today => DateTime(_now.year, _now.month, _now.day);

  List<DateTime> get _days {
    if (_periode == 2) return [_today];
    final n = _periode == 1 ? 30 : 7;
    return List.generate(n, (i) => _today.subtract(Duration(days: n - 1 - i)));
  }

  DateTime get _startDate => _days.first;

  List<Transaksi> get _filtered => _selesai
      .where((t) => t.tanggal >= _startDate.millisecondsSinceEpoch)
      .toList();

  Map<DateTime, int> get _dailyOmzet {
    final map = <DateTime, int>{for (final d in _days) d: 0};
    for (final t in _filtered) {
      final key = DateTime.fromMillisecondsSinceEpoch(t.tanggal);
      final d = DateTime(key.year, key.month, key.day);
      if (map.containsKey(d)) map[d] = map[d]! + t.totalBelanja;
    }
    return map;
  }

  Map<DateTime, int> get _dailyProfit {
    final trxIds = _filtered.map((t) => t.id).toSet();
    final profitByTrx = <int, int>{};
    for (final it in widget.allItems) {
      if (!trxIds.contains(it.transaksiId)) continue;
      profitByTrx[it.transaksiId] = (profitByTrx[it.transaksiId] ?? 0) +
          it.subtotal -
          (it.hargaModal * it.jumlah).round();
    }
    final map = <DateTime, int>{for (final d in _days) d: 0};
    for (final t in _filtered) {
      final key = DateTime.fromMillisecondsSinceEpoch(t.tanggal);
      final d = DateTime(key.year, key.month, key.day);
      if (map.containsKey(d)) {
        map[d] = map[d]! + (profitByTrx[t.id] ?? 0);
      }
    }
    return map;
  }

  int get _totalOmzet => _filtered.fold(0, (s, t) => s + t.totalBelanja);
  int get _totalProfit {
    final trxIds = _filtered.map((t) => t.id).toSet();
    int p = 0;
    for (final it in widget.allItems) {
      if (!trxIds.contains(it.transaksiId)) continue;
      p += it.subtotal - (it.hargaModal * it.jumlah).round();
    }
    return p;
  }

  int get _totalTrx => _filtered.length;
  int get _avgTrx => _totalTrx == 0 ? 0 : _totalOmzet ~/ _totalTrx;

  // Top 5 produk terlaris
  List<MapEntry<String, double>> get _topProduk {
    final trxIds = _filtered.map((t) => t.id).toSet();
    final sales = <String, double>{};
    for (final it in widget.allItems) {
      if (!trxIds.contains(it.transaksiId)) continue;
      sales[it.namaProduk] = (sales[it.namaProduk] ?? 0) + it.jumlah;
    }
    final sorted = sales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  Map<String, int> get _revenueByProduk {
    final trxIds = _filtered.map((t) => t.id).toSet();
    final rev = <String, int>{};
    for (final it in widget.allItems) {
      if (!trxIds.contains(it.transaksiId)) continue;
      rev[it.namaProduk] = (rev[it.namaProduk] ?? 0) + it.subtotal;
    }
    return rev;
  }

  List<Produk> get _stokHabis =>
      widget.produk.where((p) => p.stok <= 0).toList();
  List<Produk> get _stokMenipis =>
      widget.produk.where((p) => p.stok > 0 && p.stok <= 5).toList();

  @override
  Widget build(BuildContext context) {
    final omzetMap = _dailyOmzet;
    final profitMap = _dailyProfit;
    final days = _days;
    final maxOmzet = omzetMap.values.fold<int>(0, (m, v) => v > m ? v : m);
    final top = _topProduk;
    final rev = _revenueByProduk;
    final maxQty = top.isEmpty ? 1.0 : top.first.value;
    final isPc = MediaQuery.of(context).size.width >= 1100;
    final bottomPad = isPc ? 24.0 : 120.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
      children: [
        // Filter periode
        Row(
          children: [
            const Text('Dashboard',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: C.text)),
            const Spacer(),
            _PeriodeChip(
                label: '7H',
                active: _periode == 0,
                onTap: () => setState(() => _periode = 0)),
            const SizedBox(width: 6),
            _PeriodeChip(
                label: '30H',
                active: _periode == 1,
                onTap: () => setState(() => _periode = 1)),
            const SizedBox(width: 6),
            _PeriodeChip(
                label: 'Hari Ini',
                active: _periode == 2,
                onTap: () => setState(() => _periode = 2)),
          ],
        ),
        const SizedBox(height: 14),

        // Kartu ringkasan — adaptif per mode
        Builder(builder: (context) {
          final sw = MediaQuery.of(context).size.width;
          final cards = [
            _StatCard(
              label: 'Omzet',
              value: Formatter.rupiah(_totalOmzet),
              icon: Icons.payments_outlined,
              color: C.brand,
            ),
            _StatCard(
              label: 'Keuntungan',
              value: Formatter.rupiah(_totalProfit),
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF22C55E),
            ),
            _StatCard(
              label: 'Transaksi',
              value: '$_totalTrx',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFFF59E0B),
            ),
            _StatCard(
              label: 'Rata-rata',
              value: Formatter.rupiah(_avgTrx),
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF8B5CF6),
            ),
          ];

          if (sw >= 1100) {
            // PC: 4 kartu horizontal sejajar
            return Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i < cards.length - 1) const SizedBox(width: 10),
                ],
              ],
            );
          } else if (sw >= 600) {
            // Tablet: 2 baris x 2 kolom, tinggi fixed
            return Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 10),
                      Expanded(child: cards[1]),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: cards[2]),
                      const SizedBox(width: 10),
                      Expanded(child: cards[3]),
                    ],
                  ),
                ),
              ],
            );
          } else {
            // HP: 2 baris x 2 kolom
            return Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 10),
                      Expanded(child: cards[1]),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: cards[2]),
                      const SizedBox(width: 10),
                      Expanded(child: cards[3]),
                    ],
                  ),
                ),
              ],
            );
          }
        }),
        const SizedBox(height: 20),

        // Grafik Bar Omzet
        _SectionHeader(
          title: 'Omzet Harian',
          subtitle: _periode == 2
              ? 'Hari ini'
              : _periode == 1
                  ? '30 hari terakhir'
                  : '7 hari terakhir',
        ),
        const SizedBox(height: 10),
        Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: C.brand.withValues(alpha: 0.15), width: 1.5),
          ),
          child: days.length == 1
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Formatter.rupiah(omzetMap[days.first] ?? 0),
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: C.brand)),
                      const SizedBox(height: 4),
                      const Text('Total hari ini',
                          style: TextStyle(color: C.muted, fontSize: 13)),
                    ],
                  ),
                )
              : BarChart(
                  BarChartData(
                    maxY: maxOmzet == 0 ? 10 : maxOmzet * 1.25,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: C.borderSoft,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx < 0 || idx >= days.length) {
                              return const SizedBox.shrink();
                            }
                            // Tampilkan label setiap n agar tidak penuh
                            final step = days.length <= 7
                                ? 1
                                : days.length <= 14
                                    ? 2
                                    : 5;
                            if (idx % step != 0 && idx != days.length - 1) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              DateFormat(
                                      days.length <= 7 ? 'E' : 'd/M', 'id_ID')
                                  .format(days[idx]),
                              style:
                                  const TextStyle(fontSize: 9, color: C.muted),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(days.length, (i) {
                      final v = omzetMap[days[i]] ?? 0;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: v.toDouble(),
                            color: C.brand,
                            width: days.length <= 7
                                ? 18
                                : days.length <= 14
                                    ? 10
                                    : 6,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6)),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxOmzet == 0 ? 10 : maxOmzet * 1.25,
                              color: C.brand.withValues(alpha: 0.06),
                            ),
                          ),
                        ],
                      );
                    }),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => C.brand,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            Formatter.rupiah(rod.toY.toInt()),
                            const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          );
                        },
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 20),

        // Line chart Omzet vs Profit
        if (days.length > 1) ...[
          _SectionHeader(
            title: 'Omzet vs Keuntungan',
            subtitle: 'Perbandingan tren',
          ),
          const SizedBox(height: 10),
          Container(
            height: 190,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: C.brand.withValues(alpha: 0.15), width: 1.5),
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: C.borderSoft, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= days.length) {
                          return const SizedBox.shrink();
                        }
                        final step = days.length <= 7
                            ? 1
                            : days.length <= 14
                                ? 2
                                : 5;
                        if (idx % step != 0 && idx != days.length - 1) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          DateFormat(days.length <= 7 ? 'E' : 'd/M', 'id_ID')
                              .format(days[idx]),
                          style: const TextStyle(fontSize: 9, color: C.muted),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => C.text,
                    getTooltipItems: (spots) => spots.map((s) {
                      final isOmzet = s.barIndex == 0;
                      return LineTooltipItem(
                        Formatter.rupiah(s.y.toInt()),
                        TextStyle(
                          color: isOmzet ? C.brand : const Color(0xFF22C55E),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  // Omzet line
                  LineChartBarData(
                    spots: List.generate(
                        days.length,
                        (i) => FlSpot(
                              i.toDouble(),
                              (omzetMap[days[i]] ?? 0).toDouble(),
                            )),
                    isCurved: true,
                    color: C.brand,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: C.brand.withValues(alpha: 0.08),
                    ),
                  ),
                  // Profit line
                  LineChartBarData(
                    spots: List.generate(
                        days.length,
                        (i) => FlSpot(
                              i.toDouble(),
                              (profitMap[days[i]] ?? 0).toDouble(),
                            )),
                    isCurved: true,
                    color: const Color(0xFF22C55E),
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Legend
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: C.brand, label: 'Omzet'),
                const SizedBox(width: 16),
                _LegendDot(color: const Color(0xFF22C55E), label: 'Keuntungan'),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Produk Terlaris
        _SectionHeader(
            title: 'Produk Terlaris', subtitle: 'Berdasarkan qty terjual'),
        const SizedBox(height: 10),
        if (top.isEmpty)
          _EmptyCard(label: 'Belum ada data penjualan di periode ini')
        else
          ...top.asMap().entries.map((e) {
            final i = e.key;
            final nama = e.value.key;
            final qty = e.value.value;
            final revenue = rev[nama] ?? 0;
            final pct = maxQty == 0 ? 0.0 : qty / maxQty;
            final colors = [
              C.brand,
              const Color(0xFF8B5CF6),
              const Color(0xFF22C55E),
              const Color(0xFFF59E0B),
              const Color(0xFFEF4444),
            ];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: C.brand.withValues(alpha: 0.15), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              colors[i % colors.length].withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${i + 1}',
                            style: TextStyle(
                                color: colors[i % colors.length],
                                fontWeight: FontWeight.w800,
                                fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(nama,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Formatter.rupiah(revenue),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: colors[i % colors.length])),
                          Text('${Formatter.qty(qty)} terjual',
                              style: const TextStyle(
                                  color: C.muted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: C.surface,
                      valueColor:
                          AlwaysStoppedAnimation(colors[i % colors.length]),
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 20),

        // Info Stok
        _SectionHeader(
          title: 'Info Stok',
          subtitle:
              '${_stokHabis.length} habis, ${_stokMenipis.length} menipis',
        ),
        const SizedBox(height: 10),
        if (_stokHabis.isEmpty && _stokMenipis.isEmpty)
          _EmptyCard(label: 'Semua stok dalam kondisi baik')
        else ...[
          if (_stokHabis.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: C.danger, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('Stok Habis',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: C.danger)),
              ]),
            ),
            ..._stokHabis.map((p) => _StokCard(produk: p, habis: true)),
            const SizedBox(height: 10),
          ],
          if (_stokMenipis.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('Stok Menipis',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B))),
              ]),
            ),
            ..._stokMenipis.map((p) => _StokCard(produk: p, habis: false)),
          ],
        ],
      ],
    );
  }
}

// Helper widgets

class _PeriodeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PeriodeChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? C.brand : C.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : C.muted)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: C.muted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: color),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: C.text)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(subtitle,
              style: const TextStyle(fontSize: 11, color: C.muted),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 11, color: C.muted, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _EmptyCard extends StatelessWidget {
  final String label;
  const _EmptyCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.borderSoft),
      ),
      child: Center(
          child: Text(label,
              style: const TextStyle(color: C.muted, fontSize: 13))),
    );
  }
}

class _StokCard extends StatelessWidget {
  final Produk produk;
  final bool habis;
  const _StokCard({required this.produk, required this.habis});

  @override
  Widget build(BuildContext context) {
    final color = habis ? C.danger : const Color(0xFFF59E0B);
    final bgColor = habis ? C.dangerSoft : const Color(0xFFFFF7ED);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            habis
                ? Icons.remove_shopping_cart_rounded
                : Icons.warning_amber_rounded,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(produk.nama,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
              Text(
                  habis
                      ? 'Stok habis'
                      : 'Sisa ${Formatter.qty(produk.stok)} ${produk.satuan}',
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Text(Formatter.rupiah(produk.harga),
            style: const TextStyle(color: C.muted, fontSize: 12)),
      ]),
    );
  }
}

//  Hutang Status Chip

class _HutangStatusChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _HutangStatusChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? C.brand : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: active ? C.brand : C.borderSoft,
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: C.brand.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : C.muted,
          ),
        ),
      ),
    );
  }
}
