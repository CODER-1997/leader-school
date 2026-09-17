import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/school_student_profil/student_payment_controller.dart';
import 'payment_success_dialog.dart';

const List<String> _uzMonthNames = [
  'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
];

String monthKeyOf(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}";

String monthLabelOf(DateTime d, {bool withYear = false}) {
  final name = _uzMonthNames[d.month - 1];
  return withYear ? "$name ${d.year}" : name;
}

/// Kiritilgan raqamni "100 000" ko'rinishida (bo'shliq bilan minglik
/// guruhlab) formatlaydi — foydalanuvchi yozayotganda jonli yangilanadi.
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return const TextEditingValue(text: '');

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && (digitsOnly.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digitsOnly[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

double _parseAmount(String text) => double.tryParse(text.replaceAll(' ', '')) ?? 0;
String _formatAmountForField(double amount) {
  final digits = amount.toInt().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// To'lov qo'shish HAM tahrirlash uchun — TO'LIQ EKRAN sifatida ochiladi
/// (dialog EMAS). MUHIM: bu — bottom sheet/dialog'larda klaviatura bilan
/// to'qnashib "tepaga ko'tarilib ketish" xatosining oldini olish uchun
/// ATAYLAB shunday qilingan (boshqa to'liq ekranlarda ham shu pattern).
void showAddPaymentDialog(
    BuildContext context,
    StudentPaymentController controller,
    String studentName, {
      String? parentPhone,
      Map<String, dynamic>? existingPayment,
      String defaultSource = 'school',
      String? defaultForSubjectId,
    }) {
  Get.to(() => _AddPaymentScreen(
    controller: controller,
    studentName: studentName,
    parentPhone: parentPhone,
    existingPayment: existingPayment,
    defaultSource: defaultSource,
    defaultForSubjectId: defaultForSubjectId,
  ));
}

class _AddPaymentScreen extends StatefulWidget {
  final StudentPaymentController controller;
  final String studentName;
  final String? parentPhone;
  final Map<String, dynamic>? existingPayment;
  final String defaultSource;
  final String? defaultForSubjectId;

  const _AddPaymentScreen({
    required this.controller,
    required this.studentName,
    this.parentPhone,
    this.existingPayment,
    this.defaultSource = 'school',
    this.defaultForSubjectId,
  });

  @override
  State<_AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<_AddPaymentScreen> {
  late final bool isEdit;
  late final TextEditingController amountController;
  late DateTime selectedDate;
  late String method;
  late String source;
  String? selectedSubjectId;

  final ScrollController monthScrollController = ScrollController();
  late int selectedYear; // YANGI: tanlangan yil — shu yilning 12 oyi ko'rsatiladi
  late String selectedForMonthKey;

  // YANGI: endi qattiq 7 oylik oyna emas — TANLANGAN yilning BARCHA
  // 12 oyi. `recentMonths` nomi eski chaqiruvchilar bilan mos kelishi
  // uchun saqlab qolindi, lekin endi hisoblanadigan getter.
  List<DateTime> get recentMonths => List.generate(12, (i) => DateTime(selectedYear, i + 1, 1));

  bool _isLoadingSubjects = true;
  bool _subjectsFetchAttempted = false;
  List<Map<String, String>> _subjects = []; // [{id, name}]

  @override
  void initState() {
    super.initState();
    isEdit = widget.existingPayment != null;

    amountController = TextEditingController(
      text: isEdit ? _formatAmountForField((widget.existingPayment!['amount'] as double)) : '',
    );
    selectedDate = isEdit
        ? DateTime.fromMillisecondsSinceEpoch(widget.existingPayment!['dateMs'] ?? DateTime.now().millisecondsSinceEpoch)
        : DateTime.now();
    method = isEdit ? (widget.existingPayment!['method'] ?? 'cash') : 'cash';
    source = isEdit ? (widget.existingPayment!['source'] ?? 'school') : widget.defaultSource;
    selectedSubjectId = isEdit ? widget.existingPayment!['forSubjectId'] as String? : widget.defaultForSubjectId;

    final now = DateTime.now();
    selectedForMonthKey = isEdit ? (widget.existingPayment!['forMonth'] as String? ?? monthKeyOf(now)) : monthKeyOf(now);
    // YANGI: boshlang'ich yil — tanlangan oy kalitidan (masalan
    // "2026-08" dan "2026") olinadi.
    selectedYear = int.tryParse(selectedForMonthKey.split('-').first) ?? now.year;

    if (source == 'tutoring') {
      _ensureSubjectsLoaded();
    } else {
      _isLoadingSubjects = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentMonth());
  }

  Future<void> _ensureSubjectsLoaded() async {
    if (_subjectsFetchAttempted) return; // bir marta yetarli
    _subjectsFetchAttempted = true;
    setState(() => _isLoadingSubjects = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('center_subjects').orderBy('name').get();
      setState(() {
        _subjects = snap.docs.map((d) => {'id': d.id, 'name': (d.data()['name'] ?? 'Nomsiz fan').toString()}).toList();
        _isLoadingSubjects = false;
      });
    } catch (e) {
      setState(() => _isLoadingSubjects = false);
    }
  }

  // YANGI: manba (Maktab/Kurs) ekranning O'ZIDA o'zgartirilganda
  // chaqiriladi — shu bilan bu oyna QAYERDAN ochilishidan qat'i nazar
  // (umumiy ro'yxatdan, School'dan, Markazdan) bir xil ishlaydi.
  void _onSourceChanged(String newSource) {
    setState(() {
      source = newSource;
      if (newSource != 'tutoring') {
        // Maktabga o'tilsa — fan tanlovi endi kerak emas.
        selectedSubjectId = null;
      }
    });
    if (newSource == 'tutoring') _ensureSubjectsLoaded();
  }

  // YANGI: yil o'zgartirilganda — tanlangan OY RAQAMI saqlanadi, faqat
  // yili almashadi (masalan "Avgust 2026" tanlangan bo'lsa, 2025 ga
  // o'tilganda "Avgust 2025" bo'lib qoladi).
  void _onYearChanged(int year) {
    final currentMonthNum = int.tryParse(selectedForMonthKey.split('-')[1]) ?? DateTime.now().month;
    setState(() {
      selectedYear = year;
      selectedForMonthKey = "$year-${currentMonthNum.toString().padLeft(2, '0')}";
    });
  }

  void _scrollToCurrentMonth() {
    final now = DateTime.now();
    final idx = recentMonths.indexWhere((m) => m.year == now.year && m.month == now.month);
    if (monthScrollController.hasClients && idx > 0) {
      monthScrollController.jumpTo((idx * 76.0).clamp(0.0, monthScrollController.position.maxScrollExtent));
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    monthScrollController.dispose();
    super.dispose();
  }

  /// Shu oy uchun (VA joriy manba/fan bo'yicha) ALLAQACHON kiritilgan
  /// to'lovni topadi — bor bo'lsa, chip "to'langan" deb ko'rsatiladi,
  /// bosilsa esa uning summasi maydonga AVTOMATIK to'ldiriladi.
  Map<String, dynamic>? _existingPaymentForMonth(String monthKey) {
    for (final p in widget.controller.payments) {
      if (p['forMonth'] != monthKey) continue;
      if (p['source'] != source) continue;
      if (source == 'tutoring' && p['forSubjectId'] != selectedSubjectId) continue;
      // Tahrirlash rejimida — hozir tahrirlanayotgan to'lovning o'zini
      // "mavjud" deb hisoblamaymiz (aks holda o'zi bilan taqqoslanadi).
      if (isEdit && p['id'] == widget.existingPayment!['id']) continue;
      return p;
    }
    return null;
  }

  void _onMonthTap(String key) {
    setState(() => selectedForMonthKey = key);
    final existing = _existingPaymentForMonth(key);
    // MUHIM TUZATISH: avval faqat "to'langan" holatda maydon
    // to'ldirilardi — "to'lanmagan" oyga o'tilganda esa OLDINGI oydan
    // qolgan summa EKRANDA QOLIB KETARDI (tozalanmasdi), bu esa
    // "bu oy ham to'langan" degan noto'g'ri taassurot berardi. Endi
    // ikkala holat ham ANIQ boshqariladi.
    amountController.text = existing != null ? _formatAmountForField(existing['amount'] as double) : '';
  }

  Future<void> _handleSave() async {
    final amount = _parseAmount(amountController.text);
    if (amount <= 0) {
      Get.snackbar("Diqqat", "To'g'ri miqdor kiriting", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    if (source == 'tutoring' && selectedSubjectId == null) {
      Get.snackbar("Diqqat", "Fanni tanlang", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (isEdit) {
      final ok = await widget.controller.editPayment(
        paymentId: widget.existingPayment!['id'],
        newAmount: amount,
        newDate: selectedDate,
        newMethod: method,
        newForMonthKey: selectedForMonthKey,
        newForSubjectId: selectedSubjectId,
      );
      if (ok) Get.back();
    } else {
      final saved = await widget.controller.addPayment(
        amount: amount,
        date: selectedDate,
        method: method,
        studentName: widget.studentName,
        forMonthKey: selectedForMonthKey,
        source: source,
        forSubjectId: selectedSubjectId,
      );
      if (saved != null) {
        Get.back();
        showPaymentSuccessDialog(
          studentName: widget.studentName,
          amount: amount,
          date: selectedDate,
          method: method,
          parentPhone: widget.parentPhone,
          forMonthLabel: monthLabelOf(
            recentMonths.firstWhere((m) => monthKeyOf(m) == selectedForMonthKey, orElse: () => DateTime.now()),
            withYear: true,
          ),
        );
      }
    }
  }

  // =======================================================================
  // VIZUAL YORDAMCHI — faqat ko'rinish uchun, mantiqqa aloqasi yo'q.
  // =======================================================================
  Widget _sectionCard({required IconData icon, required String title, String? hint, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF2F6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, size: 15, color: const Color(0xFF10B981)),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)))),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(hint, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(isEdit ? "To'lovni tahrirlash" : "To'lov qo'shish", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 17)),
      ),
      // "Saqlash" tugmasi pastga MAHKAMLANGAN — scroll qilib qidirish shart emas.
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: Obx(() => ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            onPressed: widget.controller.isSaving.value ? null : _handleSave,
            child: widget.controller.isSaving.value
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : Text(isEdit ? "Saqlash" : "To'lovni saqlash", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          )),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- YANGI: MANBA TANLASH — Maktab/Kurs. Bu oyna endi
              // qaysi ekrandan ochilishidan (umumiy ro'yxat, School,
              // Markaz) qat'i nazar BIR XIL ishlaydi — chaqiruvchi
              // to'g'ri kontekst uzatmagan bo'lsa ham, shu yerda
              // qo'lda tanlash mumkin.
              _sectionCard(
                icon: Icons.category_rounded,
                title: "Manba",
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(11),
                        onTap: () => _onSourceChanged('school'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: source == 'school' ? const Color(0xFF10B981) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: source == 'school' ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                          ),
                          child: Center(
                            child: Text("Maktab", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: source == 'school' ? Colors.white : const Color(0xFF334155))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(11),
                        onTap: () => _onSourceChanged('tutoring'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: source == 'tutoring' ? const Color(0xFF10B981) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: source == 'tutoring' ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                          ),
                          child: Center(
                            child: Text("Kurs", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: source == 'tutoring' ? Colors.white : const Color(0xFF334155))),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // --- FAN TANLASH: faqat Markaz (tutoring) to'lovi uchun ---
              if (source == 'tutoring') ...[
                _sectionCard(
                  icon: Icons.menu_book_rounded,
                  title: "Qaysi fan uchun",
                  child: _isLoadingSubjects
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981))),
                  )
                      : _subjects.isEmpty
                      ? const Text("Fanlar topilmadi", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
                      : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _subjects.map((s) {
                      final selected = selectedSubjectId == s['id'];
                      return InkWell(
                        borderRadius: BorderRadius.circular(11),
                        onTap: () => setState(() => selectedSubjectId = s['id']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF10B981) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: selected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(s['name']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF334155))),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // --- MIQDORI — TO'LIQ KENGLIKDA (xavfsiz, siqishmaydi) ---
              _sectionCard(
                icon: Icons.payments_rounded,
                title: "Miqdori (so'm)",
                child: TextField(
                  controller: amountController,
                  autofocus: !isEdit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ThousandsSeparatorInputFormatter()],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: "500 000",
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // --- SANA — TO'LIQ KENGLIKDA ---
              _sectionCard(
                icon: Icons.calendar_today_rounded,
                title: "Sana",
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Text(DateFormat('dd.MM.yyyy').format(selectedDate), style: const TextStyle(fontSize: 14.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // --- QAYSI OY UCHUN ---
              _sectionCard(
                icon: Icons.calendar_month_rounded,
                title: "Qaysi oy uchun",
                hint: "Yashil belgi bor oy — to'lov mavjud, bosing.",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // YANGI: YIL TANLASH — tanlangan yilga qarab pastdagi
                    // oylar ro'yxati o'zgaradi (o'sha yilning 12 oyi).
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 4,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, i) {
                          final year = DateTime.now().year - 2 + i;
                          final isSelected = year == selectedYear;
                          return InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () => _onYearChanged(year),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF10B981) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                "$year",
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF334155)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 66,
                      child: ListView.separated(
                        controller: monthScrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: recentMonths.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final m = recentMonths[i];
                          final key = monthKeyOf(m);
                          final selected = key == selectedForMonthKey;
                          final existingForThisMonth = _existingPaymentForMonth(key);
                          final bool alreadyPaid = existingForThisMonth != null;

                          return InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: () => _onMonthTap(key),
                            child: Container(
                              width: 62,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: selected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: selected ? 1.5 : 1),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 13,
                                    child: alreadyPaid ? const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)) : null,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    monthLabelOf(m).substring(0, 3),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? const Color(0xFF10B981) : const Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 1),
                                  Text("${m.year}", style: TextStyle(fontSize: 9.5, color: selected ? const Color(0xFF10B981) : const Color(0xFF94A3B8))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // --- TO'LOV TURI ---
              _sectionCard(
                icon: Icons.credit_card_rounded,
                title: "To'lov turi",
                child: Row(
                  children: [
                    Expanded(child: _MethodChip(label: "Naqt", icon: Icons.payments_outlined, selected: method == 'cash', onTap: () => setState(() => method = 'cash'))),
                    const SizedBox(width: 8),
                    Expanded(child: _MethodChip(label: "Karta", icon: Icons.credit_card_rounded, selected: method == 'card', onTap: () => setState(() => method = 'card'))),
                    const SizedBox(width: 8),
                    Expanded(child: _MethodChip(label: "O'tkazma", icon: Icons.account_balance_rounded, selected: method == 'bank_transfer', onTap: () => setState(() => method = 'bank_transfer'))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10B981).withOpacity(0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: selected ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: selected ? const Color(0xFF10B981) : const Color(0xFF334155))),
          ],
        ),
      ),
    );
  }
}