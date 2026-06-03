import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../features/transaction/domain/models/transaction_model.dart';

// Web-only import
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show Blob, Url, AnchorElement;

class CsvExportService {
  static String _buildCsv(List<TransactionModel> transactions, String projectName) {
    final formatter = DateFormat('yyyy-MM-dd');
    final buf = StringBuffer();

    buf.writeln('날짜,내용,금액,유형,가계부');

    for (final tx in transactions) {
      final date = formatter.format(tx.date);
      final desc = '"${tx.description.replaceAll('"', '""')}"';
      final amount = tx.amount.toInt();
      final type = tx.isIncome ? '수입' : '지출';
      final project = '"${projectName.replaceAll('"', '""')}"';
      buf.writeln('$date,$desc,$amount,$type,$project');
    }

    return buf.toString();
  }

  static Future<void> export({
    required List<TransactionModel> transactions,
    required String projectName,
  }) async {
    final csv = _buildCsv(transactions, projectName);
    final filename = '${projectName}_${DateFormat('yyyyMM').format(DateTime.now())}.csv';

    if (kIsWeb) {
      _downloadWeb(csv, filename);
    } else {
      await Clipboard.setData(ClipboardData(text: csv));
    }
  }

  static void _downloadWeb(String csv, String filename) {
    final bom = '\uFEFF'; // UTF-8 BOM for Excel compatibility
    final blob = html.Blob(['$bom$csv'], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
