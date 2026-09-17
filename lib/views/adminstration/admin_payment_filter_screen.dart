import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/admin_controller/admin_payment_controller.dart'; // MUHIM: sizning haqiqiy yo'lingizga moslang
import 'admin_payment_report_results_screen.dart';

/// To'lovlar hisoboti uchun FILTR ekrani: manba (Maktab/Kurs/Ikkalasi)
/// + sana oralig'i tanlanadi, "Ko'rish" bosilsa natijalar ekraniga
/// o'tiladi (u yerdan Excel ham olinadi).
class AdminPaymentFilterScreen extends StatefulWidget {
  final AdminPaymentsController controller;

  const AdminPaymentFilterScreen({super.key, required this.controller});

  @override
  State<AdminPaymentFilterScreen> createState() => _AdminPaymentFilterScreenState();
}

class _AdminPaymentFilterScreenState extends State<AdminPaymentFilterScreen> {
  // null = Ikkalasi, 'school' = Maktab, 'tutoring' = Kurs
  String? _selectedSource;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  void _setQuickRange(DateTime start, DateTime end) {
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
    });
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: (_rangeStart != null && _rangeEnd != null) ? DateTimeRange(start: _rangeStart!, end: _rangeEnd!) : null,
    );
    if (range != null) {
      setState(() {
        _rangeStart = range.start;
        _rangeEnd = range.end;
      });
    }
  }

  bool get _canProceed => _rangeStart != null && _rangeEnd != null;

  void _proceed() {
    if (!_canProceed) return;
    final endOfDay = DateTime(_rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day, 23, 59, 59);
    Get.to(() => AdminPaymentReportResultsScreen(
      controller: widget.controller,
      source: _selectedSource,
      start: _rangeStart!,
      end: endOfDay,
    ));
  }

  Widget _sourceChip(String label, String? value, IconData icon) {
    final bool isSelected = _selectedSource == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedSource = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : const Color(0xFF64748B), size: 22),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickOption(String label, VoidCallback onTap, {required bool isSelected}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981).withOpacity(0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 18, color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
            if (isSelected) const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0);
    final last3MonthsStart = DateTime(now.year, now.month - 3, 1);

    final bool isCurrentMonth = _rangeStart == currentMonthStart && _rangeEnd == currentMonthEnd;
    final bool isLast3Months = _rangeStart == last3MonthsStart && _rangeEnd?.day == now.day && _rangeEnd?.month == now.month && _rangeEnd?.year == now.year;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("To'lovlar hisoboti", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Manba", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Row(
              children: [
                _sourceChip("Maktab", 'school', Icons.school_rounded),
                const SizedBox(width: 10),
                _sourceChip("Kurs", 'tutoring', Icons.groups_rounded),
                const SizedBox(width: 10),
                _sourceChip("Ikkalasi", null, Icons.all_inclusive_rounded),
              ],
            ),
            const SizedBox(height: 24),

            const Text("Vaqt diapazoni", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            _quickOption("Joriy oy", () => _setQuickRange(currentMonthStart, currentMonthEnd), isSelected: isCurrentMonth),
            const SizedBox(height: 8),
            _quickOption("Oxirgi 3 oy", () => _setQuickRange(last3MonthsStart, now), isSelected: isLast3Months),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickCustomRange,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (_rangeStart != null && _rangeEnd != null && !isCurrentMonth && !isLast3Months)
                            ? "${DateFormat('dd.MM.yyyy').format(_rangeStart!)} – ${DateFormat('dd.MM.yyyy').format(_rangeEnd!)}"
                            : "Boshqa davr tanlash...",
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canProceed ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _canProceed ? _proceed : null,
                icon: Icon(Icons.visibility_rounded, color: _canProceed ? Colors.white : const Color(0xFF94A3B8)),
                label: Text("Ko'rish", style: TextStyle(color: _canProceed ? Colors.white : const Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 15.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}