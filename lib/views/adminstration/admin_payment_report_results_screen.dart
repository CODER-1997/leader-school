import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/admin_controller/admin_payment_controller.dart'; // MUHIM: sizning haqiqiy yo'lingizga moslang
import '../../services/excel_report_service.dart'; // MUHIM: shu ham

/// Filtrlangan davr uchun to'lov "cheklari" ro'yxati — jami summasi
/// bilan. AppBar'dagi "Excel" tugmasi aynan shu (filtrlangan) ma'lumot
/// bo'yicha hisobot yaratadi.
class AdminPaymentReportResultsScreen extends StatefulWidget {
  final AdminPaymentsController controller;
  final String? source; // null = ikkalasi
  final DateTime start;
  final DateTime end;

  const AdminPaymentReportResultsScreen({
    super.key,
    required this.controller,
    required this.source,
    required this.start,
    required this.end,
  });

  @override
  State<AdminPaymentReportResultsScreen> createState() => _AdminPaymentReportResultsScreenState();
}

class _AdminPaymentReportResultsScreenState extends State<AdminPaymentReportResultsScreen> {
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;
  List<PaymentRecord> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await widget.controller.fetchPaymentsInRange(
        start: widget.start,
        end: widget.end,
        source: widget.source,
      );
      if (!mounted) return;
      setState(() {
        _payments = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double get _total => _payments.fold(0.0, (sum, p) => sum + p.amount);

  String get _sourceLabel {
    if (widget.source == 'school') return "Maktab";
    if (widget.source == 'tutoring') return "Kurs";
    return "Maktab + Kurs";
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'card':
        return "Karta";
      case 'bank_transfer':
        return "Bank o'tkazmasi";
      default:
        return "Naqd";
    }
  }

  String _paymentSourceLabel(String source) => source == 'tutoring' ? "Kurs" : "Maktab";

  Future<void> _exportExcel() async {
    if (_payments.isEmpty) {
      Get.snackbar("Diqqat", "Bu davrda to'lov topilmadi", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    setState(() => _isExporting = true);
    try {
      await ExcelReportService.generateAndShare(payments: _payments, start: widget.start, end: widget.end);
      Get.snackbar("Tayyor", "${_payments.length} ta to'lov bo'yicha hisobot yaratildi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xatolik", "Hisobot yaratishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat("#,###", "uz");

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(_sourceLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _isExporting ? null : _exportExcel,
              icon: _isExporting
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                  : const Icon(Icons.grid_on_rounded, size: 18, color: Color(0xFF10B981)),
              label: const Text("Excel", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _error != null
          ? Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFECACA))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                  SizedBox(width: 8),
                  Text("Yuklashda xato", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(_error!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontFamily: 'monospace')),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        color: const Color(0xFF10B981),
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${DateFormat('dd.MM.yyyy').format(widget.start)} – ${DateFormat('dd.MM.yyyy').format(widget.end)}",
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  const SizedBox(height: 6),
                  Text("${currencyFormat.format(_total)} so'm", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("${_payments.length} ta to'lov", style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_payments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      const Text("Bu davrda to'lov topilmadi", style: TextStyle(color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              )
            else
              ..._payments.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEEF2F6)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (p.isLocked ? const Color(0xFF94A3B8) : const Color(0xFF10B981)).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        p.isLocked ? Icons.lock_rounded : Icons.check_circle_outline_rounded,
                        color: p.isLocked ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
                          const SizedBox(height: 2),
                          Text(
                            "${_paymentSourceLabel(p.source)} · ${_methodLabel(p.method)}"
                                "${p.date != null ? ' · ${DateFormat('dd.MM.yyyy').format(p.date!)}' : ''}",
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    Text("+${currencyFormat.format(p.amount)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981))),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}