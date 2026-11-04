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

