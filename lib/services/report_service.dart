import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import '../utils/formatter.dart';

class ReportService {
  ReportService._();
  static final ReportService i = ReportService._();

  Future<File> generateExcel({
    required String storeName,
    required List<Transaksi> transactions,
    String? dateRange,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Laporan Transaksi'];
    // Hapus sheet default jika ada
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#4F46E5'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    sheet.appendRow([TextCellValue('LAPORAN TRANSAKSI - $storeName')]);
    sheet.appendRow([
      TextCellValue(
          'Tanggal Cetak: ${Formatter.tanggal(DateTime.now().millisecondsSinceEpoch)}')
    ]);
    if (dateRange != null && dateRange.isNotEmpty) {
      sheet.appendRow([TextCellValue('Periode: $dateRange')]);
    }
    sheet.appendRow([]);

    final headerRowIndex = sheet.maxRows;
    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Tanggal'),
      TextCellValue('Metode'),
      TextCellValue('Total Belanja'),
      TextCellValue('Dibayar'),
      TextCellValue('Kembalian'),
      TextCellValue('Status'),
      TextCellValue('Nama Hutang'),
    ]);
    for (var i = 0; i < 8; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: i, rowIndex: headerRowIndex))
          .cellStyle = headerStyle;
    }

    int totalOmzet = 0;
    for (final t in transactions) {
      if (t.status == 'selesai') totalOmzet += t.totalBelanja;
      sheet.appendRow([
        IntCellValue(t.noUrut),
        TextCellValue(Formatter.tanggal(t.tanggal)),
        TextCellValue(t.metode.toUpperCase()),
        IntCellValue(t.totalBelanja),
        IntCellValue(t.totalBayar),
        IntCellValue(t.kembalian),
        TextCellValue(t.status.toUpperCase()),
        TextCellValue(t.namaHutang),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('TOTAL OMZET (selesai)'),
      TextCellValue(''),
      TextCellValue(''),
      IntCellValue(totalOmzet),
    ]);

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/Laporan_Ngical_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return file;
  }

  Future<File> generatePdf({
    required String storeName,
    required List<Transaksi> transactions,
    String? dateRange,
  }) async {
    final pdf = pw.Document();
    final omzet = transactions
        .where((t) => t.status == 'selesai')
        .fold(0, (s, t) => s + t.totalBelanja);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(storeName,
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text('Laporan Transaksi',
                    style: const pw.TextStyle(
                        fontSize: 14, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Dicetak: ${Formatter.tanggal(DateTime.now().millisecondsSinceEpoch)}',
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            if (dateRange != null && dateRange.isNotEmpty)
              pw.Text('Periode: $dateRange',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.indigo600),
              rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(
                          color: PdfColors.grey300, width: 0.5))),
              cellHeight: 28,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              headers: ['No', 'Tanggal', 'Metode', 'Status', 'Total'],
              data: transactions
                  .map((t) => [
                        '#${t.noUrut}',
                        Formatter.tanggal(t.tanggal),
                        t.metode.toUpperCase(),
                        t.status.toUpperCase(),
                        Formatter.rupiah(t.totalBelanja),
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Total Pendapatan: ',
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  Formatter.rupiah(omzet),
                  style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo700),
                ),
              ],
            ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/Laporan_Ngical_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }
}
