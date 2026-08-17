import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/admin_controller/admin_payment_controller.dart'; // MUHIM: sizning haqiqiy yo'lingizga moslang

/// To'lovlar bo'yicha BATAFSIL Excel hisobotini yaratadi va ulashadi.
///
/// MUHIM: pubspec.yaml'ga qo'shing: flutter pub add excel
///
/// 3 ta varaq (sheet):
///   1. "Sheet1" (standart) — Xulosa: jami summalar, manba/tur bo'yicha taqsimot
///   2. "Kunlik taqsimot" — tanlangan davrdagi har bir kun uchun summa
///   3. "Tafsilotlar" — har bir to'lov alohida qator sifatida
///
/// MUHIM: bu yerda faqat TASDIQLANGAN, xavfsiz API ishlatildi (cell
/// stilizatsiyasi/ustun kengligi kabi noaniq metodlar ataylab
/// qo'shilmadi) — share_plus'da bo'lgani kabi versiya nomuvofiqligi
/// xavfini kamaytirish uchun. Ma'lumotning o'zi to'liq va to'g'ri.
class ExcelReportService {
  ExcelReportService._();

  static Future<void> generateAndShare({
    required List<PaymentRecord> payments,
    required DateTime start,
    required DateTime end,
  }) async {
    final excel = Excel.createExcel();

    _buildSummarySheet(excel, payments, start, end);
    _buildDailySheet(excel, payments);
    _buildDetailsSheet(excel, payments);

    final bytes = excel.save();
    if (bytes == null) throw Exception("Excel fayl yaratib bo'lmadi");

    final dir = await getTemporaryDirectory();
    final fileName = "tolovlar_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}.xlsx";
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: "To'lovlar hisoboti (${DateFormat('dd.MM.yyyy').format(start)} – ${DateFormat('dd.MM.yyyy').format(end)})",
    );
  }

  static void _setCell(Sheet sheet, int col, int row, CellValue value) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value = value;
  }

  // --- 1. XULOSA (standart "Sheet1" ichida) ---
  static void _buildSummarySheet(Excel excel, List<PaymentRecord> payments, DateTime start, DateTime end) {
    final sheet = excel['Sheet1'];

    double total = 0;
    double schoolTotal = 0, tutoringTotal = 0;
    int schoolCount = 0, tutoringCount = 0;
    double cashTotal = 0, cardTotal = 0, transferTotal = 0;

    for (final p in payments) {
      total += p.amount;
      if (p.source == 'school') {
        schoolTotal += p.amount;
        schoolCount++;
      } else {
        tutoringTotal += p.amount;
        tutoringCount++;
      }
      switch (p.method) {
        case 'card':
          cardTotal += p.amount;
          break;
        case 'bank_transfer':
          transferTotal += p.amount;
          break;
        default:
          cashTotal += p.amount;
      }
    }

    int row = 0;
    void addRow(String label, String value) {
      _setCell(sheet, 0, row, TextCellValue(label));
      _setCell(sheet, 1, row, TextCellValue(value));
      row++;
    }

    addRow("TO'LOVLAR HISOBOTI", "");
    addRow("Davr", "${DateFormat('dd.MM.yyyy').format(start)} - ${DateFormat('dd.MM.yyyy').format(end)}");
    addRow("Yaratilgan sana", DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()));
    row++;
    addRow("Jami to'lovlar soni", "${payments.length}");
    addRow("Jami summa", "${_fmt(total)} so'm");
    row++;
    addRow("Maktab (soni)", "$schoolCount");
    addRow("Maktab (summasi)", "${_fmt(schoolTotal)} so'm");
    addRow("Repetitorlik (soni)", "$tutoringCount");
    addRow("Repetitorlik (summasi)", "${_fmt(tutoringTotal)} so'm");
    row++;
    addRow("Naqd", "${_fmt(cashTotal)} so'm");
    addRow("Karta", "${_fmt(cardTotal)} so'm");
    addRow("Bank o'tkazmasi", "${_fmt(transferTotal)} so'm");
  }

  // --- 2. KUNLIK TAQSIMOT ---
  static void _buildDailySheet(Excel excel, List<PaymentRecord> payments) {
    final sheet = excel['Kunlik taqsimot'];

    _setCell(sheet, 0, 0, TextCellValue("Sana"));
    _setCell(sheet, 1, 0, TextCellValue("To'lovlar soni"));
    _setCell(sheet, 2, 0, TextCellValue("Summa (so'm)"));

    final Map<String, List<PaymentRecord>> byDay = {};
    for (final p in payments) {
      if (p.date == null) continue;
      final key = DateFormat('dd.MM.yyyy').format(p.date!);
      byDay.putIfAbsent(key, () => []).add(p);
    }

    final sortedKeys = byDay.keys.toList()
      ..sort((a, b) => DateFormat('dd.MM.yyyy').parse(a).compareTo(DateFormat('dd.MM.yyyy').parse(b)));

    int row = 1;
    for (final key in sortedKeys) {
      final dayPayments = byDay[key]!;
      final dayTotal = dayPayments.fold(0.0, (sum, p) => sum + p.amount);
      _setCell(sheet, 0, row, TextCellValue(key));
      _setCell(sheet, 1, row, IntCellValue(dayPayments.length));
      _setCell(sheet, 2, row, DoubleCellValue(dayTotal));
      row++;
    }
  }

  // --- 3. TAFSILOTLAR ---
  static void _buildDetailsSheet(Excel excel, List<PaymentRecord> payments) {
    final sheet = excel['Tafsilotlar'];

    final headers = ["No", "O'quvchi", "Summa (so'm)", "Manba", "To'lov turi", "Sana", "Holat"];
    for (int i = 0; i < headers.length; i++) {
      _setCell(sheet, i, 0, TextCellValue(headers[i]));
    }

    int row = 1;
    for (final p in payments) {
      _setCell(sheet, 0, row, IntCellValue(row));
      _setCell(sheet, 1, row, TextCellValue(p.studentName));
      _setCell(sheet, 2, row, DoubleCellValue(p.amount));
      _setCell(sheet, 3, row, TextCellValue(p.source == 'tutoring' ? "Repetitorlik" : "Maktab"));
      _setCell(sheet, 4, row, TextCellValue(_methodLabel(p.method)));
      _setCell(sheet, 5, row, TextCellValue(p.date != null ? DateFormat('dd.MM.yyyy').format(p.date!) : ''));
      _setCell(sheet, 6, row, TextCellValue(p.isLocked ? "Qulflangan" : "Ochiq"));
      row++;
    }
  }

  static String _fmt(double v) => NumberFormat("#,###", "uz").format(v);

  static String _methodLabel(String method) {
    switch (method) {
      case 'card':
        return "Karta";
      case 'bank_transfer':
        return "Bank o'tkazmasi";
      default:
        return "Naqd";
    }
  }
}

// =========================================================================
// YANGI METOD — buni AdminPaymentsController klassi ICHIGA qo'shing
// (masalan lockPaymentsInRange metodidan keyin). Butun faylni emas,
// FAQAT shu metodni qo'shing.
// =========================================================================

