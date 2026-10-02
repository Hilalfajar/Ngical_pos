/// Konversi QRIS Static → QRIS Dynamic dengan nominal tertanam.
///
/// Standar: EMV QCPM (Specification for QRIS Indonesia, BI).
/// Format payload: TLV (Tag 2-digit, Length 2-digit, Value).
///
/// Langkah:
///  1. Parse semua TLV dari QRIS Static.
///  2. Ubah tag 01 (Point of Initiation Method) dari "11" → "12".
///  3. Sisipkan tag 54 (Transaction Amount) dengan nominal.
///  4. Hapus tag 63 (CRC lama).
///  5. Rekonstruksi string, tambah "6304" di akhir, hitung CRC-16, append.
library qris_dynamic;

class QrisDynamic {
  QrisDynamic._();

  /// Menghasilkan string QRIS Dynamic dari [staticQris] dengan [amount] (rupiah).
  /// Kembalikan null jika [staticQris] tidak valid / bukan format QRIS.
  static String? generate(String staticQris, int amount) {
    if (staticQris.isEmpty || amount <= 0) return null;

    final raw = staticQris.trim();

    // Validasi minimal: harus diawali "000201"
    if (!raw.startsWith('000201')) return null;

    // Parse semua TLV
    final tlvs = <_Tlv>[];
    int i = 0;
    while (i < raw.length) {
      if (i + 4 > raw.length) break;
      final tag = raw.substring(i, i + 2);
      final lenStr = raw.substring(i + 2, i + 4);
      final len = int.tryParse(lenStr);
      if (len == null) break;
      if (i + 4 + len > raw.length) break;
      final value = raw.substring(i + 4, i + 4 + len);
      tlvs.add(_Tlv(tag, value));
      i += 4 + len;
    }

    if (tlvs.isEmpty) return null;

    // Modifikasi / sisipkan tag yang diperlukan
    bool hasAmount = false;
    final result = <_Tlv>[];

    for (final tlv in tlvs) {
      if (tlv.tag == '63') {
        // Hapus CRC lama — akan dihitung ulang di akhir
        continue;
      }
      if (tlv.tag == '01') {
        // Ubah Point of Initiation: 11 (static) → 12 (dynamic)
        result.add(_Tlv('01', '12'));
        continue;
      }
      if (tlv.tag == '54') {
        // Ganti nominal yang sudah ada (jika ada)
        hasAmount = true;
        result.add(_Tlv('54', _formatAmount(amount)));
        continue;
      }
      result.add(tlv);
    }

    // Kalau belum ada tag 54, sisipkan sebelum tag 55 / 58 / 59 / 60 / 62
    // Standar menyarankan tag 54 sebelum tag 55 (tip) atau di antara 52–58.
    if (!hasAmount) {
      final amountTlv = _Tlv('54', _formatAmount(amount));
      // Cari posisi yang tepat: setelah tag 53 (currency) atau sebelum 55/58/59/60
      int insertIdx = result.length;
      for (int j = 0; j < result.length; j++) {
        final t = int.tryParse(result[j].tag) ?? 0;
        if (t >= 55) {
          insertIdx = j;
          break;
        }
      }
      result.insert(insertIdx, amountTlv);
    }

    // Rekonstruksi string tanpa CRC
    final buf = StringBuffer();
    for (final tlv in result) {
      buf.write(tlv.tag);
      final len = tlv.value.length.toString().padLeft(2, '0');
      buf.write(len);
      buf.write(tlv.value);
    }

    // Tambah "6304" (tag 63, panjang 04) sebagai basis hitung CRC
    buf.write('6304');

    final crc = _crc16(buf.toString());
    buf.write(crc);

    return buf.toString();
  }

  /// Format nominal ke string tanpa desimal (QRIS tidak pakai desimal untuk IDR).
  static String _formatAmount(int amount) => amount.toString();

  /// CRC-16/CCITT-FALSE — polynomial 0x1021, init 0xFFFF, no reflect, no final XOR.
  static String _crc16(String data) {
    int crc = 0xFFFF;
    for (final char in data.codeUnits) {
      crc ^= (char << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}

class _Tlv {
  final String tag;
  final String value;
  const _Tlv(this.tag, this.value);
}
