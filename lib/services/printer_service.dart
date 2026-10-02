import 'dart:io';
import 'dart:ui' as ui;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/formatter.dart';
import '../utils/qris_dynamic.dart';

/// Hasil satu operasi print, dipakai biar UI bisa kasih tahu user
/// sukses/gagal + alasannya, bukan cuma bool doang.
class PrintResult {
  final bool success;
  final String message;
  const PrintResult(this.success, this.message);

  static const okBluetooth =
      PrintResult(true, 'Berhasil dikirim ke printer Bluetooth');
  static const okWifi = PrintResult(true, 'Berhasil dikirim ke printer WiFi');
  static const okWindows =
      PrintResult(true, 'Struk dikirim ke printer Windows');
}

/// Satu perangkat Bluetooth yang sudah ter-pairing di HP.
class PairedPrinter {
  final String name;
  final String macAddress;
  const PairedPrinter(this.name, this.macAddress);
}

/// Service untuk cetak struk ke printer thermal ESC/POS beneran,
/// bukan cuma simpan pengaturan. Mendukung Bluetooth (via
/// print_bluetooth_thermal, Android/iOS) dan WiFi/LAN (kirim byte
/// ESC/POS mentah lewat TCP socket ke IP:port, umumnya port 9100).
///
/// USB belum didukung di sini. Dukungan plugin USB thermal printer
/// di Flutter masih sangat terbatas/kurang terawat, jadi sengaja
/// tidak dipalsukan seolah-olah jalan.
class PrinterService {
  PrinterService._();
  static final PrinterService i = PrinterService._();

  String? _connectedMac;
  String? get connectedMac => _connectedMac;

  /// Ambil daftar perangkat Bluetooth yang sudah di-pairing di
  /// pengaturan Bluetooth HP (printer harus di-pairing dulu manual
  /// lewat Settings > Bluetooth sebelum muncul di sini).
  ///
  /// Melempar Exception dengan pesan yang jelas kalau Bluetooth mati
  /// atau izin belum diberikan, supaya UI bisa kasih tahu user harus
  /// ngapain, bukan cuma spin terus tanpa penjelasan.
  Future<List<PairedPrinter>> getPairedBluetoothDevices() async {
    if (Platform.isAndroid) {
      // Pastikan izin lengkap. Di Android 12+ butuh Nearby Devices (Connect/Scan).
      // Di Android lama butuh Location.
      // Request permissions
      await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();

      // Cek satu-satu untuk kepastian
      if (await Permission.bluetoothConnect.isDenied) {
        throw Exception(
            'Izin "Perangkat Terdekat" (Bluetooth Connect) ditolak.');
      }
    }

    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      throw Exception(
          'Bluetooth HP mati. Aktifkan Bluetooth agar bisa mendeteksi printer.');
    }

    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list.map((b) => PairedPrinter(b.name, b.macAdress)).toList();
  }

  Future<bool> connectBluetooth(String macAddress) async {
    try {
      // Pastikan diskonek dulu biar bersih, beberapa printer rese kalau
      // ditumpuk koneksinya.
      await PrintBluetoothThermal.disconnect;
      await Future.delayed(const Duration(milliseconds: 500));

      final ok =
          await PrintBluetoothThermal.connect(macPrinterAddress: macAddress)
              .timeout(const Duration(seconds: 12), onTimeout: () => false);

      if (ok) {
        _connectedMac = macAddress;
      } else {
        // Coba sekali lagi dengan delay, kadang socket bluetooth telat ready.
        await Future.delayed(const Duration(seconds: 1));
        final retryOk =
            await PrintBluetoothThermal.connect(macPrinterAddress: macAddress)
                .timeout(const Duration(seconds: 12), onTimeout: () => false);
        if (retryOk) _connectedMac = macAddress;
        return retryOk;
      }
      return ok;
    } catch (e) {
      return false;
    }
  }

  Future<bool> get isBluetoothConnected =>
      PrintBluetoothThermal.connectionStatus;

  Future<void> disconnectBluetooth() async {
    await PrintBluetoothThermal.disconnect;
    _connectedMac = null;
  }

  /// Susun byte ESC/POS untuk satu struk. paperWidthMm harus '58' atau '80'.
  Future<List<int>> buildReceiptBytes({
    required String paperWidthMm,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required bool
        printLogo, // reserved: cetak gambar logo, lihat catatan di bawah
    required bool printFooter,
    required String footerText,
    required List<ReceiptLine> items,
    required int total,
    required int bayar,
    required int kembalian,
    required String metode,
    required String trxNo,
    required DateTime tanggal,
    String qrisToken = '',
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidthMm == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final g = Generator(paper, profile);
    final bytes = <int>[];

    bytes.addAll(g.reset());

    bytes.addAll(g.text(
      storeName,
      styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2),
    ));
    if (storeAddress.isNotEmpty) {
      bytes.addAll(g.text(storeAddress,
          styles: const PosStyles(align: PosAlign.center)));
    }
    if (storePhone.isNotEmpty) {
      bytes.addAll(
          g.text(storePhone, styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(g.hr());

    bytes.addAll(g.text('No: $trxNo'));
    bytes.addAll(g.text(_fmtTanggal(tanggal)));
    bytes.addAll(g.hr());

    for (final it in items) {
      bytes.addAll(g.text(it.nama));
      bytes.addAll(g.row([
        PosColumn(
            text: '${Formatter.qty(it.qty)} x ${_rp(it.harga)}', width: 7),
        PosColumn(
            text: _rp(it.subtotal),
            width: 5,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    bytes.addAll(g.hr());

    bytes.addAll(g.row([
      PosColumn(text: 'Total', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
          text: _rp(total),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]));
    bytes.addAll(g.row([
      PosColumn(
          text: metode.toUpperCase() == 'CASH' ? 'Bayar' : 'Metode', width: 6),
      PosColumn(
        text:
            metode.toUpperCase() == 'CASH' ? _rp(bayar) : metode.toUpperCase(),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    if (metode == 'cash') {
      bytes.addAll(g.row([
        PosColumn(text: 'Kembali', width: 6),
        PosColumn(
            text: _rp(kembalian),
            width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    // Cetak QR QRIS jika metode QRIS dan token tersedia
    if (metode.toLowerCase() == 'qris' && qrisToken.isNotEmpty) {
      final dynamicQris = QrisDynamic.generate(qrisToken, total) ?? qrisToken;
      bytes.addAll(g.hr());
      bytes.addAll(g.text('Scan QRIS untuk Pembayaran',
          styles: const PosStyles(align: PosAlign.center)));
      try {
        final qrImage = await _generateQrImageBytes(dynamicQris);
        if (qrImage != null) {
          bytes.addAll(g.image(qrImage));
        }
      } catch (_) {
        bytes.addAll(g.text(dynamicQris,
            styles: const PosStyles(align: PosAlign.center)));
      }
    }

    if (printFooter && footerText.isNotEmpty) {
      bytes.addAll(g.hr());
      bytes.addAll(
          g.text(footerText, styles: const PosStyles(align: PosAlign.center)));
    }

    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  /// Render QR code dari [data] ke [img.Image] untuk ESC/POS.
  Future<img.Image?> _generateQrImageBytes(String data) async {
    try {
      final painter = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );
      // Render ke PNG bytes via picture recorder
      const size = 200.0;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, size, size),
      );
      // paint() returns void, tidak perlu await
      painter.paint(canvas, const Size(size, size));
      final picture = recorder.endRecording();
      final uiImage = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final pngBytes = byteData.buffer.asUint8List();
      final decoded = img.decodePng(pngBytes);
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Future<PrintResult> printBluetooth(List<int> bytes) async {
    final connected = await isBluetoothConnected;
    if (!connected) {
      return const PrintResult(false, 'Printer Bluetooth belum terhubung');
    }
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    return ok
        ? PrintResult.okBluetooth
        : const PrintResult(false, 'Gagal mengirim data ke printer Bluetooth');
  }

  Future<PrintResult> printWifi({
    required String ip,
    required String port,
    required List<int> bytes,
  }) async {
    Socket? socket;
    try {
      final p = int.tryParse(port) ?? 9100;
      socket = await Socket.connect(ip, p, timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      return PrintResult.okWifi;
    } on SocketException catch (e) {
      return PrintResult(false,
          'Gagal konek ke printer WiFi ($ip:$port): ${e.osError?.message ?? e.message}');
    } catch (e) {
      return PrintResult(false, 'Gagal mencetak: $e');
    } finally {
      await socket?.close();
    }
  }

  /// Ambil daftar printer sistem (Windows / macOS / Linux) yang terpasang.
  /// Mengembalikan list kosong kalau platform tidak mendukung atau gagal.
  Future<List<Printer>> listSystemPrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (_) {
      return [];
    }
  }

  /// Buat PDF struk untuk printer Windows / sistem.
  /// Ukuran kertas mengikuti paperWidthMm (58 / 80) agar cocok thermal.
  Future<pw.Document> buildReceiptPdf({
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required bool printFooter,
    required String footerText,
    required List<ReceiptLine> items,
    required int total,
    required int bayar,
    required int kembalian,
    required String metode,
    required String trxNo,
    required DateTime tanggal,
    String paperWidthMm = '80',
    String qrisToken = '',
  }) async {
    final doc = pw.Document();
    final title = storeName.isEmpty ? 'Struk' : storeName;
    // roll58 / roll80 dari package pdf
    final pageFormat =
        paperWidthMm == '58' ? PdfPageFormat.roll57 : PdfPageFormat.roll80;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                title,
                textAlign: pw.TextAlign.center,
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              if (storeAddress.isNotEmpty)
                pw.Text(
                  storeAddress,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              if (storePhone.isNotEmpty)
                pw.Text(
                  storePhone,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.Text('No: $trxNo', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(_fmtTanggal(tanggal),
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(),
              ...items.map((it) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text(it.nama, style: const pw.TextStyle(fontSize: 10)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${Formatter.qty(it.qty)} x ${_rp(it.harga)}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(_rp(it.subtotal),
                              style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_rp(total),
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    metode.toUpperCase() == 'CASH' ? 'Bayar' : 'Metode',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    metode.toUpperCase() == 'CASH'
                        ? _rp(bayar)
                        : metode.toUpperCase(),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              if (metode == 'cash')
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Kembali', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(_rp(kembalian),
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              // QR code QRIS di struk PDF
              if (metode.toLowerCase() == 'qris' && qrisToken.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.Text(
                  'Scan QRIS untuk Pembayaran',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: QrisDynamic.generate(qrisToken, total) ?? qrisToken,
                    width: 120,
                    height: 120,
                    drawText: false,
                  ),
                ),
                pw.SizedBox(height: 4),
              ],
              if (printFooter && footerText.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.Text(
                  footerText,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ],
          );
        },
      ),
    );
    return doc;
  }

  /// Cetak ke printer sistem.
  ///
  /// - Kalau [printerName] / [printerUrl] diisi (sudah dipilih di menu Printer),
  ///   pakai [Printing.directPrintPdf] → **tidak ada dialog**.
  /// - Kalau kosong, fallback ke [Printing.layoutPdf] (dialog print Windows).
  Future<PrintResult> printWindowsSystem(
    pw.Document doc, {
    String printerName = '',
    String printerUrl = '',
    String paperWidthMm = '80',
  }) async {
    try {
      final pageFormat =
          paperWidthMm == '58' ? PdfPageFormat.roll57 : PdfPageFormat.roll80;

      // Direct print kalau user sudah pilih printer spesifik
      if (printerName.isNotEmpty || printerUrl.isNotEmpty) {
        // Cari Printer object yang cocok dari daftar sistem
        final printers = await listSystemPrinters();
        Printer? target;
        for (final p in printers) {
          if ((printerUrl.isNotEmpty && p.url == printerUrl) ||
              (printerName.isNotEmpty && p.name == printerName)) {
            target = p;
            break;
          }
        }
        // Fallback: buat Printer object dari nama/url yang tersimpan
        target ??= Printer(
            url: printerUrl.isNotEmpty ? printerUrl : printerName,
            name: printerName);

        final ok = await Printing.directPrintPdf(
          printer: target,
          onLayout: (format) async => doc.save(),
          name: 'Struk Ngical',
          format: pageFormat,
        );
        if (ok) return PrintResult.okWindows;
        return const PrintResult(
            false, 'Cetak dibatalkan atau gagal dikirim ke printer');
      }

      // Belum pilih printer spesifik → buka dialog seperti biasa
      final ok = await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name: 'Struk Ngical',
        format: pageFormat,
      );
      if (ok) return PrintResult.okWindows;
      return const PrintResult(false, 'Cetak dibatalkan');
    } catch (e) {
      return PrintResult(false, 'Gagal cetak Windows: $e');
    }
  }

  String _rp(int v) => 'Rp${v.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      )}';

  String _fmtTanggal(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class ReceiptLine {
  final String nama;
  final double qty;
  final int harga;
  final int subtotal;
  const ReceiptLine({
    required this.nama,
    required this.qty,
    required this.harga,
    required this.subtotal,
  });
}
