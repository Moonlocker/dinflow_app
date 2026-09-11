import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/category.dart';
import '../../../models/transaction.dart';

/// Dados necessários para gerar um relatório exportável.
class ReportExportData {
  const ReportExportData({
    required this.periodLabel,
    required this.transactions,
    required this.categories,
    required this.income,
    required this.expense,
  });

  final String periodLabel;
  final List<Transaction> transactions;
  final List<Category> categories;
  final double income;
  final double expense;

  double get balance => income - expense;
}

/// Gera relatórios em PDF e Excel e abre o compartilhamento do sistema.
class ReportExporter {
  const ReportExporter._();

  static String _fileDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _categoryName(ReportExportData data, String? id) {
    for (final category in data.categories) {
      if (category.id == id) return category.name;
    }
    return '-';
  }

  static List<Transaction> _sorted(ReportExportData data) {
    final list = List<Transaction>.from(data.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static Future<void> exportPdf(ReportExportData data) async {
    final document = pw.Document();
    final rows = _sorted(data);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'DinFlow - Relatório Financeiro',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text('Período: ${data.periodLabel}'),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryBox('Entradas', data.income, PdfColors.green700),
              _summaryBox('Saídas', data.expense, PdfColors.red700),
              _summaryBox('Saldo', data.balance, PdfColors.blue700),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Transações (${rows.length})',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Data', 'Descrição', 'Categoria', 'Tipo', 'Valor'],
            data: [
              for (final transaction in rows)
                [
                  formatDateOnly(transaction.date.toIso8601String()),
                  transaction.description ?? '-',
                  _categoryName(data, transaction.categoryId),
                  transaction.isIncome ? 'Entrada' : 'Saída',
                  formatCurrency(transaction.amount),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    final bytes = await document.save();
    await _share(bytes, 'DinFlow-Relatorio-${_fileDate()}.pdf', 'application/pdf');
  }

  static pw.Widget _summaryBox(String label, double value, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(
          formatCurrency(value),
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  static Future<void> exportExcel(ReportExportData data) async {
    final excel = Excel.createExcel();

    final summary = excel['Resumo'];
    summary.appendRow([TextCellValue('Relatório DinFlow')]);
    summary.appendRow([TextCellValue('Período'), TextCellValue(data.periodLabel)]);
    summary.appendRow([TextCellValue('Entradas'), DoubleCellValue(data.income)]);
    summary.appendRow([TextCellValue('Saídas'), DoubleCellValue(data.expense)]);
    summary.appendRow([TextCellValue('Saldo'), DoubleCellValue(data.balance)]);

    final sheet = excel['Transações'];
    sheet.appendRow([
      TextCellValue('Data'),
      TextCellValue('Descrição'),
      TextCellValue('Categoria'),
      TextCellValue('Tipo'),
      TextCellValue('Valor'),
    ]);
    for (final transaction in _sorted(data)) {
      sheet.appendRow([
        TextCellValue(formatDateOnly(transaction.date.toIso8601String())),
        TextCellValue(transaction.description ?? '-'),
        TextCellValue(_categoryName(data, transaction.categoryId)),
        TextCellValue(transaction.isIncome ? 'Entrada' : 'Saída'),
        DoubleCellValue(transaction.amount),
      ]);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Falha ao gerar o arquivo Excel.');
    }
    await _share(
      bytes,
      'DinFlow-Relatorio-${_fileDate()}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  static Future<void> _share(
    List<int> bytes,
    String fileName,
    String mimeType,
  ) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: 'Relatório DinFlow',
      ),
    );
  }
}
