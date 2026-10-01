import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app.dart';
import '../theme.dart';
import '../utils/formatter.dart';
import '../utils/toast.dart';

/// Kelola bahan baku (terpisah dari produk jual) untuk perhitungan HPP.
class BahanPage extends StatefulWidget {
  final bool embeddedPc;
  final bool embeddedPcFormOnly;
  const BahanPage({
    super.key,
    this.embeddedPc = false,
    this.embeddedPcFormOnly = false,
  });
  @override
  State<BahanPage> createState() => _BahanPageState();
}

class _BahanPageState extends State<BahanPage> {
  final _q = TextEditingController();
  String query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _openForm({Bahan? bahan}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BahanForm(bahan: bahan),
    );
  }

  void _openRestok(Bahan b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RestokSheet(bahan: b),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    final list = a.bahan.where((b) {
      if (query.isEmpty) return true;
      return b.nama.toLowerCase().contains(query.toLowerCase());
    }).toList();

    // PC panel kanan: form tambah bahan
    if (widget.embeddedPcFormOnly) {
      return const ColoredBox(
        color: Colors.white,
        child: BahanForm(embedded: true),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Container(
            height: 46,
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
                  child:
                      const Icon(Icons.search_rounded, color: C.brand, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _q,
                    onChanged: (v) => setState(() => query = v),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      hintText: 'Cari bahan...',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: C.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Cari Bahan',
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
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.science_outlined,
                            size: 48, color: C.muted.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text('Belum ada bahan baku',
                            style: TextStyle(
                                color: C.muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        const SizedBox(height: 6),
                        Text(
                          widget.embeddedPc
                              ? 'Isi form di panel kanan untuk menambah bahan'
                              : 'Tambah bahan (alpukat, susu, dll)\nuntuk dibuat resep HPP',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: C.faint, fontSize: 12),
                        ),
                        // Tombol "Tambah Bahan Baku" di empty state dihilangkan:
                        // - PC: pakai form kanan
                        // - Tablet/HP: pakai FAB bawah saja
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final b = list[i];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openForm(bahan: b),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: C.brandLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.eco_outlined,
                                    color: C.brand, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.nama,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Beli ${Formatter.qty(b.jumlahBeli)} ${b.satuan} = ${Formatter.rupiah(b.hargaBeli)}',
                                      style: const TextStyle(
                                          fontSize: 11, color: C.muted),
                                    ),
                                    Text(
                                      '≈ ${Formatter.rupiah(b.hargaPerSatuan)} / ${b.satuan}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: C.brand,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Stok',
                                    style: TextStyle(
                                        fontSize: 10, color: C.muted),
                                  ),
                                  Text(
                                    '${Formatter.qty(b.stok)} ${b.satuan}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: b.stok > 0 ? C.text : C.danger,
                                    ),
                                  ),
                                ],
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'restok') {
                                    _openRestok(b);
                                  } else if (v == 'edit') {
                                    _openForm(bahan: b);
                                  } else if (v == 'hapus') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Hapus bahan?'),
                                        content: Text(
                                            'Hapus "${b.nama}"? Resep yang memakai bahan ini juga akan terpengaruh.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Batal')),
                                          FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Hapus')),
                                        ],
                                      ),
                                    );
                                    if (ok == true && b.id != null) {
                                      await context
                                          .read<App>()
                                          .deleteBahan(b.id!);
                                      if (context.mounted) {
                                        AppToast.success(
                                            context, 'Bahan dihapus');
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'restok',
                                      child: Text('Restok')),
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(
                                      value: 'hapus', child: Text('Hapus')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class BahanForm extends StatefulWidget {
  final Bahan? bahan;
  final bool embedded;
  const BahanForm({super.key, this.bahan, this.embedded = false});
  @override
  State<BahanForm> createState() => _BahanFormState();
}

class _BahanFormState extends State<BahanForm> {
  late final TextEditingController _nama;
  late final TextEditingController _hargaBeli;
  late final TextEditingController _jumlahBeli;
  late final TextEditingController _stok;
  String _satuan = 'g';

  static const _satuanOptions = ['g', 'ml', 'pcs', 'kg', 'liter', 'ons'];

  @override
  void initState() {
    super.initState();
    final b = widget.bahan;
    _nama = TextEditingController(text: b?.nama ?? '');
    _hargaBeli =
        TextEditingController(text: b != null ? '${b.hargaBeli}' : '');
    _jumlahBeli =
        TextEditingController(text: b != null ? '${b.jumlahBeli}' : '1');
    _stok = TextEditingController(text: b != null ? '${b.stok}' : '0');
    _satuan = b?.satuan ?? 'g';
  }

  @override
  void dispose() {
    _nama.dispose();
    _hargaBeli.dispose();
    _jumlahBeli.dispose();
    _stok.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nama = _nama.text.trim();
    final hb = int.tryParse(_hargaBeli.text) ?? 0;
    final jb = double.tryParse(_jumlahBeli.text) ?? 0;
    final st = double.tryParse(_stok.text) ?? 0;
    if (nama.isEmpty || jb <= 0) {
      AppToast.error(context, 'Nama & jumlah beli wajib diisi');
      return;
    }
    await context.read<App>().saveBahan(Bahan(
          id: widget.bahan?.id,
          nama: nama,
          satuan: _satuan,
          hargaBeli: hb,
          jumlahBeli: jb,
          stok: st,
        ));
    if (mounted) {
      if (!widget.embedded) Navigator.pop(context);
      AppToast.success(context, 'Bahan disimpan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.bahan != null;
    final hb = int.tryParse(_hargaBeli.text) ?? 0;
    final jb = double.tryParse(_jumlahBeli.text) ?? 0;
    final perSatuan = jb > 0 ? (hb / jb).round() : 0;

    final mq = MediaQuery.of(context);
    final maxW = mq.size.width > 640 ? 560.0 : mq.size.width;
    final maxH = mq.size.height * 0.9;

    final formColumn = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.embedded) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      isEdit ? 'Edit Bahan' : 'Tambah Bahan',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
            if (!widget.embedded) ...[
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
            const SizedBox(height: 14),
            Text(isEdit ? 'Edit Bahan' : 'Tambah Bahan',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ],
            TextField(
              controller: _nama,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('Nama bahan', 'Contoh: Alpukat'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _jumlahBeli,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: _dec('Jumlah beli', '10'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _satuan,
                    decoration: _dec('Satuan', null),
                    items: _satuanOptions
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _satuan = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hargaBeli,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: _dec(
                  'Harga beli total (Rp) - acuan HPP', '10000'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.brandLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Harga per $_satuan ≈ ${Formatter.rupiah(perSatuan)} (untuk resep)',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: C.brand, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stok,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec(
                  'Stok gudang sekarang ($_satuan)', '0'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tips: untuk isi ulang stok, pakai menu Restok (titik 3) - tidak perlu edit resep.',
              style: TextStyle(fontSize: 11, color: C.muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: C.brand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Simpan Bahan',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
    );

    if (widget.embedded) {
      return Material(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + mq.viewInsets.bottom),
          child: formColumn,
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, 20 + mq.viewInsets.bottom),
            child: formColumn,
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, String? hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: C.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: C.borderSoft),
        ),
        isDense: true,
      );
}

/// Sheet cepat untuk restok (tambah stok tanpa ubah resep)
class _RestokSheet extends StatefulWidget {
  final Bahan bahan;
  const _RestokSheet({required this.bahan});

  @override
  State<_RestokSheet> createState() => _RestokSheetState();
}

class _RestokSheetState extends State<_RestokSheet> {
  final _qty = TextEditingController();
  final _harga = TextEditingController();

  @override
  void dispose() {
    _qty.dispose();
    _harga.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qty.text.replaceAll(',', '.')) ?? 0;
    final harga = int.tryParse(_harga.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    if (qty <= 0) {
      AppToast.error(context, 'Jumlah restok wajib diisi');
      return;
    }
    if (harga <= 0) {
      AppToast.error(context, 'Harga beli total wajib diisi');
      return;
    }
    await context.read<App>().restokBahan(widget.bahan, qty, harga);
    if (mounted) {
      Navigator.pop(context);
      AppToast.success(context, 'Stok ${widget.bahan.nama} ditambah');
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bahan;
    final mq = MediaQuery.of(context);
    final qty = double.tryParse(_qty.text.replaceAll(',', '.')) ?? 0;
    final harga = int.tryParse(_harga.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    final perSatuan = qty > 0 ? (harga / qty).round() : 0;
    final maxW = mq.size.width > 640 ? 560.0 : mq.size.width;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + mq.viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const SizedBox(height: 14),
                Text('Restok: ${b.nama}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Stok sekarang: ${Formatter.qty(b.stok)} ${b.satuan}',
                  style: const TextStyle(fontSize: 12, color: C.muted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Jumlah yang dibeli (${b.satuan})',
                    hintText: '10',
                    filled: true,
                    fillColor: C.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _harga,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Harga beli total (Rp)',
                    hintText: '20000',
                    filled: true,
                    fillColor: C.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.brandLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    qty > 0
                        ? 'Stok jadi ${Formatter.qty(b.stok + qty)} ${b.satuan}  |  Harga baru ≈ ${Formatter.rupiah(perSatuan)} / ${b.satuan}'
                        : 'Isi jumlah & harga pembelian',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: C.brand,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Resep produk tidak berubah. Hanya stok & harga modal yang diupdate.',
                  style: TextStyle(fontSize: 11, color: C.muted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: C.brand,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Simpan Restok',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
