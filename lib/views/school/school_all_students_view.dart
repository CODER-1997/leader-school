import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/debt_sms_preview_view.dart';
import 'student_profil/student_profil.dart'; // MUHIM: haqiqiy yo'lingizga moslang
import '../../controllers/crm_controller.dart'; // YANGI: MUHIM — haqiqiy yo'lingizga moslang

// YANGI (SMS TANLASH): tanlangan o'quvchilarni ko'rish va qarzdorlik
// haqida SMS yuborish ekrani — Markaz bo'limida ishlatilgan XUDDI
// SHU ekran shu yerda ham qayta ishlatilmoqda. MUHIM: quyidagi yo'lni
// debt_sms_preview_view.dart fayli haqiqatda qayerda yotishiga qarab
// moslang (masalan, agar u markaz papkasida bo'lsa: '../markaz/debt_sms_preview_view.dart').

String _capitalize(String text) {
  if (text.isEmpty) return '';
  return text.trim().split(' ').map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

/// "O'quvchilar" bo'limi — MAKTABDAGI (classId bor) barcha o'quvchilar,
/// ism bo'yicha jonli qidiruv. Arxivlangan o'quvchilar ko'rinmaydi.
///
/// YANGI (O'quv Markaz tomonida qilingan ishlar bu yerga ham ko'chirildi):
///   1. Ro'yxat endi Firestore'dan to'g'ridan-to'g'ri EMAS, balki
///      CrmController.allStudents — ilovaning boshqa joylarida
///      (SubjectStudentsController orqali) ALLAQACHON yuklangan umumiy
///      keshdan o'qiladi. READ = 0.
///   2. AppBar ostida SINF FILTRI (chip'lar) — "Hammasi" + har bir
///      sinf; bosilsa ro'yxat shu sinfga filtrlanadi.
///   3. Telefon o'rniga QARZDORLIK — har bir o'quvchi maktabga
///      qo'shilgan (joinedDate) oyidan bugungacha TO'LANMAGAN oylar
///      "2023 Sent, 2026 Okt" kabi ko'rsatiladi. Imtiyozli o'quvchilar
///      ozod.
///   4. Ism-familiya ALIFBO tartibida ko'rsatiladi.
///
/// YANGI (SMS TANLASH + SINFNI BELGILASH + SMS YASHIL BELGI, Markaz
/// bo'limidagi bilan bir xil naqsh): ro'yxatdagi o'quvchini UZOQ
/// BOSISH orqali "tanlov rejimi"ga o'tish mumkin — tanlangan
/// o'quvchilarga qarzdorlik haqida ommaviy SMS yuborish uchun. ANIQ
/// BIR SINF tanlanganda ("Hammasi" emas) ro'yxat ustida "Sinfni
/// belgilash" tugmasi chiqadi — bu orqali o'sha sinfdagi BARCHA
/// o'quvchini bir bosishda tanlash mumkin. Qachon oxirgi marta
/// qarzdorlik SMS'i yuborilgani YASHIL rangda ko'rsatiladi.
class SchoolAllStudentsView extends StatefulWidget {
  const SchoolAllStudentsView({super.key});

  @override
  State<SchoolAllStudentsView> createState() => _SchoolAllStudentsViewState();
}

class _SchoolAllStudentsViewState extends State<SchoolAllStudentsView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // --- Sinf filtri ---
  bool _isLoadingClasses = true;
  List<Map<String, String>> _classes = []; // [{id, name}]
  String? _selectedClassFilter; // null = filtrsiz (hammasi)

  // --- Qarzdorlik uchun to'lovlar keshi ---
  bool _isLoadingPayments = true;
  // studentId -> {"YYYY-MM", ...} — TO'LANGAN oylar (Maktab to'lovi uchun subjectId kerak emas)
  Map<String, Set<String>> _paidMonthsByStudent = {};

  // --- YANGI: qaysi o'quvchiga qachon qarzdorlik SMS'i yuborilgani ---
  Map<String, Timestamp> _lastDebtSmsByStudent = {};

  // --- YANGI (SMS TANLASH): ko'p tanlov rejimi ---
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  final Map<String, Map<String, dynamic>> _selectedDataById = {};

  static const List<String> _uzMonthShort = [
    'Yan', 'Fev', 'Mar', 'Apr', 'May', 'Iyun', 'Iyul', 'Avg', 'Sent', 'Okt', 'Noy', 'Dek'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _query = _searchController.text.trim().toLowerCase()));
    _loadClasses();
    _loadPayments();
    _loadDebtSmsStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('school_classes').orderBy('name').get();
      if (!mounted) return;
      setState(() {
        _classes = snap.docs.map((d) => {'id': d.id, 'name': (d.data()['name'] ?? 'Nomsiz sinf').toString()}).toList();
        _isLoadingClasses = false;
      });
    } catch (e) {
      debugPrint("Sinflarni yuklashda xato: $e");
      if (mounted) setState(() => _isLoadingClasses = false);
    }
  }

  /// Barcha 'school' to'lovlarini BIR MARTA — payments_feed (tekis
  /// kolleksiya) orqali — yuklaydi.
  Future<void> _loadPayments() async {
    setState(() => _isLoadingPayments = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('payments_feed')
          .where('source', isEqualTo: 'school')
          .get();

      final Map<String, Set<String>> result = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String?;
        final forMonth = data['forMonth'] as String?;
        if (studentId == null || forMonth == null) continue;
        result.putIfAbsent(studentId, () => {}).add(forMonth);
      }

      if (!mounted) return;
      setState(() {
        _paidMonthsByStudent = result;
        _isLoadingPayments = false;
      });
    } catch (e) {
      debugPrint("To'lovlarni yuklashda xato: $e");
      if (mounted) setState(() => _isLoadingPayments = false);
    }
  }

  // YANGI: 'sms_feed' kolleksiyasidan (source == 'debt') har bir
  // o'quvchiga OXIRGI marta qachon qarzdorlik SMS'i yuborilganini
  // BITTA so'rov bilan o'qiydi — Markaz bo'limidagi bilan bir xil
  // naqsh (real-time listener EMAS, bitta .get(), keyin pastga
  // tortib yangilanadi).
  Future<void> _loadDebtSmsStatus() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sms_feed')
          .where('source', isEqualTo: 'debt')
          .get();

      final Map<String, Timestamp> result = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String?;
        final sentAt = data['sentAt'] as Timestamp?;
        if (studentId == null || sentAt == null) continue;

        final existing = result[studentId];
        if (existing == null || sentAt.compareTo(existing) > 0) {
          result[studentId] = sentAt;
        }
      }

      if (!mounted) return;
      setState(() => _lastDebtSmsByStudent = result);
    } catch (e) {
      debugPrint("SMS holatini yuklashda xato: $e");
    }
  }

  // YANGI: SMS yuborilgan sanani qisqa, o'qish oson shaklda ko'rsatadi.
  String _formatSmsDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return "bugun";
    if (diff == 1) return "kecha";
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return dt.year == now.year ? "$dd.$mm" : "$dd.$mm.${dt.year}";
  }

  String _fullName(Map<String, dynamic> data) {
    final firstName = _capitalize((data['firstName'] ?? '').toString());
    final lastName = _capitalize((data['lastName'] ?? '').toString());
    return (lastName.isNotEmpty && firstName.isNotEmpty) ? "$lastName $firstName" : _capitalize((data['name'] ?? 'Nomsiz').toString());
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  // YANGI (REFAKTOR): endi xom "YYYY-MM" qarzdor oy kalitlarini
  // qaytaradi — _computeDebtMonths (ro'yxat uchun) va _debtEntries
  // (SMS preview uchun) shu funksiyadan foydalanadi, xatti-harakat
  // o'zgarmagan.
  List<String> _debtMonthKeys(String studentId, Map<String, dynamic> data) {
    if (data['isPrivileged'] == true) return [];

    final joinTs = data['joinedDate'] as Timestamp?;
    if (joinTs == null) return []; // qo'shilgan sana noma'lum bo'lsa, qarz hisoblanmaydi

    final joinDate = joinTs.toDate();
    final paidMonths = _paidMonthsByStudent[studentId] ?? {};

    final now = DateTime.now();
    final currentMonthKey = DateTime(now.year, now.month);

    final List<String> debtKeys = [];
    DateTime cursor = DateTime(joinDate.year, joinDate.month);
    while (!cursor.isAfter(currentMonthKey)) {
      final monthKey = "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}";
      if (!paidMonths.contains(monthKey)) debtKeys.add(monthKey);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return debtKeys;
  }

  String _monthKeyToLabel(String key) {
    final parts = key.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    return "$year ${_uzMonthShort[month - 1]}";
  }

  /// Bu o'quvchi uchun QARZDORLIK OYLARINI hisoblaydi — maktabga
  /// qo'shilgan (joinedDate) oyidan bugungacha to'lanmagan oylar.
  /// Imtiyozli o'quvchi bo'lsa — bo'sh ro'yxat (ozod).
  List<String> _computeDebtMonths(String studentId, Map<String, dynamic> data) {
    return _debtMonthKeys(studentId, data).map(_monthKeyToLabel).toList();
  }

  // YANGI (SMS TANLASH): DebtSmsPreviewView xuddi Markaz bo'limidagidek
  // {subjectId, subjectName, monthKey} shaklidagi yozuvlarni kutadi —
  // maktabda "fan" tushunchasi yo'q, shu sababli barcha yozuvlar uchun
  // umumiy "Maktab to'lovi" nomi ishlatiladi.
  List<Map<String, String>> _debtEntries(String studentId, Map<String, dynamic> data) {
    return _debtMonthKeys(studentId, data)
        .map((monthKey) => {'subjectId': 'maktab', 'subjectName': "Maktab to'lovi", 'monthKey': monthKey})
        .toList();
  }

  // --- YANGI (SMS TANLASH): tanlov yordamchilari ---

  void _toggleSelect(Map<String, dynamic> data) {
    final id = data['id'] as String;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectedDataById.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
        _selectedDataById[id] = data;
        _selectionMode = true;
      }
    });
  }

  // YANGI (SINFNI BELGILASH): joriy sinf filtri bo'yicha ko'rinib
  // turgan ro'yxatdagi BARCHA o'quvchilarni bir yo'la tanlaydi (yoki
  // bekor qiladi).
  void _toggleSelectAll(List<Map<String, dynamic>> selectable, bool select) {
    setState(() {
      for (final s in selectable) {
        final id = s['id'] as String;
        if (select) {
          _selectedIds.add(id);
          _selectedDataById[id] = s;
        } else {
          _selectedIds.remove(id);
          _selectedDataById.remove(id);
        }
      }
      _selectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
      _selectedDataById.clear();
    });
  }

  void _openDebtSmsPreview() {
    final selected = _selectedDataById.values.toList();
    final Map<String, List<Map<String, String>>> debtEntriesByStudent = {
      for (final s in selected) (s['id'] as String): _debtEntries(s['id'] as String, s),
    };

    Get.to(() => DebtSmsPreviewView(
      students: selected,
      debtEntriesByStudent: debtEntriesByStudent,
      fullNameBuilder: _fullName,
      monthLabelBuilder: _monthKeyToLabel,
    ))?.then((_) {
      // YANGI: ko'rish ekranidan qaytgach tanlovni tozalaymiz.
      _clearSelection();
    });
  }

  Widget _buildClassFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _classes.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            if (i == 0) {
              final isActive = _selectedClassFilter == null;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _selectedClassFilter = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Text("Hammasi", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isActive ? Colors.white : const Color(0xFF334155))),
                  ),
                ),
              );
            }
            final cls = _classes[i - 1];
            final isActive = cls['id'] == _selectedClassFilter;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _selectedClassFilter = cls['id']),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Text(cls['name']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isActive ? Colors.white : const Color(0xFF334155))),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // YANGI (SINFNI BELGILASH): faqat ANIQ BIR SINF tanlanganda
  // ko'rinadigan qator — "Sinfni belgilash" tugmasi shu sinfdagi
  // BARCHA o'quvchini bir bosishda tanlaydi/bekor qiladi.
  Widget _buildSelectAllBar(List<Map<String, dynamic>> selectable) {
    final allSelected = selectable.isNotEmpty && selectable.every((s) => _selectedIds.contains(s['id']));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Sinfda: ${selectable.length} ta o'quvchi",
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          ),
          TextButton.icon(
            onPressed: selectable.isEmpty ? null : () => _toggleSelectAll(selectable, !allSelected),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(
              allSelected ? Icons.remove_done_rounded : Icons.done_all_rounded,
              size: 17,
              color: const Color(0xFF3B82F6),
            ),
            label: Text(
              allSelected ? "Sinfni bekor qilish" : "Sinfni belgilash",
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
            ),
          ),
        ],
      ),
    );
  }

  // YANGI (SMS TANLASH): tanlangan o'quvchilar soni, "Bekor qilish" va
  // "Ko'rish" tugmalarini o'z ichiga olgan suzuvchi panel.
  Widget _buildSelectionBar() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "${_selectedIds.length} ta o'quvchi tanlandi",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
              TextButton(
                onPressed: _clearSelection,
                child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: _openDebtSmsPreview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text("Ko'rish"),
              ),
            ],
          ),
        ),
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
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text("O'quvchilar", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      // YANGI (SMS TANLASH): endi Stack ichida — tanlov paneli butun
      // ekran ustidan suzib chiqishi uchun.
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Ism bo'yicha qidirish...",
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
                    ),
                  ),
                ),

                if (!_isLoadingClasses && _classes.isNotEmpty) _buildClassFilterRow(),

                Expanded(
                  // YANGI: Obx + CrmController.allStudents — READ = 0,
                  // ilovaning boshqa joylarida allaqachon yuklangan
                  // umumiy keshdan o'qiydi.
                  child: Obx(() {
                    if (!Get.isRegistered<CrmController>()) {
                      return const Center(child: Text("Ma'lumot topilmadi", style: TextStyle(color: Color(0xFF94A3B8))));
                    }
                    final crm = Get.find<CrmController>();

                    var students = crm.allStudents.where((s) {
                      if (s['isArchived'] == true) return false;
                      final classId = s['classId'] as String?;
                      return classId != null && classId.isNotEmpty; // faqat MAKTAB o'quvchilari
                    }).toList();

                    if (_selectedClassFilter != null) {
                      students = students.where((s) => s['classId'] == _selectedClassFilter).toList();
                    }

                    if (_query.isNotEmpty) {
                      students = students.where((s) => _fullName(s).toLowerCase().contains(_query)).toList();
                    }

                    students.sort((a, b) => _fullName(a).compareTo(_fullName(b)));

                    // YANGI (SINFNI BELGILASH): "Sinfni belgilash" faqat
                    // ANIQ BIR SINF tanlanganda ko'rinadi — "Hammasi"
                    // holatida (butun maktab) bu tugma chiqmaydi.
                    final selectableClassStudents = _selectedClassFilter == null ? <Map<String, dynamic>>[] : students;

                    return Column(
                      children: [
                        if (selectableClassStudents.isNotEmpty) _buildSelectAllBar(selectableClassStudents),
                        Expanded(
                          child: RefreshIndicator(
                            color: const Color(0xFF10B981),
                            onRefresh: () async {
                              await _loadClasses();
                              await _loadPayments();
                              await _loadDebtSmsStatus();
                            },
                            child: students.isEmpty
                                ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.5,
                                  child: const Center(child: Text("O'quvchi topilmadi", style: TextStyle(color: Color(0xFF94A3B8)))),
                                ),
                              ],
                            )
                                : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                              itemCount: students.length,
                              itemBuilder: (context, index) {
                                final data = students[index];
                                final studentId = data['id'] as String;
                                final name = _fullName(data);
                                final isSelected = _selectedIds.contains(studentId);

                                final debtMonths = _isLoadingPayments ? null : _computeDebtMonths(studentId, data);
                                // YANGI: shu o'quvchiga oxirgi marta
                                // qarzdorlik SMS'i qachon yuborilgani (bo'lsa).
                                final lastDebtSms = _lastDebtSmsByStudent[studentId];

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    // YANGI (SMS TANLASH): tanlov rejimida
                                    // oddiy bosish profilga o'tkazish o'rniga
                                    // tanlash/bekor qilishga xizmat qiladi.
                                    onTap: () {
                                      if (_selectionMode) {
                                        _toggleSelect(data);
                                      } else {
                                        Get.to(() => StudentProfileView(
                                          studentId: studentId,
                                          subjectId: '', // umumiy ro'yxatdan — aniq fan konteksti yo'q
                                          studentName: name,
                                          fromCenterContext: false,
                                        ));
                                      }
                                    },
                                    // YANGI (SMS TANLASH): uzoq bosish —
                                    // tanlov rejimini boshlaydi (yoki shu
                                    // o'quvchini qo'shadi/olib tashlaydi).
                                    onLongPress: () => _toggleSelect(data),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.06) : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                                          width: isSelected ? 1.4 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // YANGI (SMS TANLASH): tanlov
                                          // rejimida avatar o'rniga
                                          // checkbox-doira chiqadi.
                                          _selectionMode
                                              ? AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            height: 40,
                                            width: 40,
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
                                                width: 2,
                                              ),
                                            ),
                                            child: isSelected
                                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                                : null,
                                          )
                                              : CircleAvatar(
                                            radius: 20,
                                            backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                                            child: Text(_initials(name), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 14.5)),
                                                const SizedBox(height: 3),
                                                // YANGI: telefon o'rniga qarzdorlik.
                                                if (debtMonths == null)
                                                  const Text("Hisoblanmoqda...", style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)))
                                                else if (debtMonths.isEmpty)
                                                  const Row(
                                                    children: [
                                                      Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                                                      SizedBox(width: 4),
                                                      Text("Qarzi yo'q", style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                                                    ],
                                                  )
                                                else
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFDC2626)),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          "Qarz: ${debtMonths.join(', ')}",
                                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                // YANGI (SMS YASHIL BELGI):
                                                // qarzdorlik haqida SMS
                                                // allaqachon yuborilgan
                                                // bo'lsa, YASHIL rangda
                                                // ko'rsatamiz.
                                                if (lastDebtSms != null) ...[
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.mark_email_read_rounded, size: 12, color: Color(0xFF10B981)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        "Qarz SMS: ${_formatSmsDate(lastDebtSms.toDate())}",
                                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          if (!_selectionMode)
                                            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),

            // YANGI (SMS TANLASH): pastda suzuvchi tanlov paneli — faqat
            // kamida 1 ta o'quvchi tanlanganda ko'rinadi.
            if (_selectedIds.isNotEmpty) _buildSelectionBar(),
          ],
        ),
      ),
    );
  }
}