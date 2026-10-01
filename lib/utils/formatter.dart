import 'package:intl/intl.dart';

class Formatter {
  static final _rp = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static String rupiah(int v) => _rp.format(v);

  static String tanggal(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(d);
  }

  static String qty(double v) {
    if (v == v.toInt()) return v.toInt().toString();
    return v.toString();
  }
}
/// Konversi satuan untuk resep HPP.
/// qty di database selalu disimpan dalam satuan dasar bahan.
class UnitConv {
  /// Faktor ke satuan dasar kategori (gram untuk massa, ml untuk volume, 1 untuk pcs)
  static const Map<String, double> _toBase = {
    // Massa → gram
    'mg': 0.001,
    'gram': 1,
    'g': 1,
    'ons': 100,
    'kg': 1000,
    'ton': 1000000,
    // Volume → ml
    'ml': 1,
    'liter': 1000,
    'l': 1000,
    // Hitungan
    'pcs': 1,
    'buah': 1,
    'lembar': 1,
    'bungkus': 1,
    'pack': 1,
    'box': 1,
    'ikat': 1,
    'porsi': 1,
  };

  static String normalize(String s) {
    final t = s.trim().toLowerCase();
    if (t == 'g') return 'gram';
    if (t == 'l') return 'liter';
    return t;
  }

  static String category(String satuan) {
    final s = normalize(satuan);
    if (['mg', 'gram', 'ons', 'kg', 'ton'].contains(s)) return 'mass';
    if (['ml', 'liter'].contains(s)) return 'volume';
    return 'count';
  }

  /// Satuan yang kompatibel dengan satuan dasar bahan
  static List<String> compatibleUnits(String bahanSatuan) {
    switch (category(bahanSatuan)) {
      case 'mass':
        return ['gram', 'ons', 'kg', 'ton'];
      case 'volume':
        return ['ml', 'liter'];
      default:
        return [normalize(bahanSatuan)];
    }
  }

  /// Ubah [qty] dari [fromUnit] ke [toUnit] (harus kategori sama)
  static double convert(double qty, String fromUnit, String toUnit) {
    final f = normalize(fromUnit);
    final t = normalize(toUnit);
    if (f == t) return qty;
    final fb = _toBase[f];
    final tb = _toBase[t];
    if (fb == null || tb == null || tb == 0) return qty;
    if (category(f) != category(t)) return qty;
    return qty * fb / tb;
  }

  /// Pilih satuan tampilan yang nyaman dari qty (dalam satuan bahan)
  static String bestDisplayUnit(double qtyInBase, String bahanSatuan) {
    final base = normalize(bahanSatuan);
    final cat = category(base);
    if (cat == 'count') return base;

    if (cat == 'mass') {
      // qtyInBase dalam satuan [base]
      final inGram = convert(qtyInBase, base, 'gram');
      if (inGram >= 1000000) return 'ton';
      if (inGram >= 1000) return 'kg';
      if (inGram >= 100) return 'ons';
      return 'gram';
    }
    if (cat == 'volume') {
      final inMl = convert(qtyInBase, base, 'ml');
      if (inMl >= 1000) return 'liter';
      return 'ml';
    }
    return base;
  }
}

