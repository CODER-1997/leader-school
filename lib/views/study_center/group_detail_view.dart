import 'package:cloud_firestore/cloud_firestore.dart'; // YANGI: fan nomini tekshirish uchun (Ingliz tili guruhimi yoki yo'q)
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // YANGI: sana ko'rsatish uchun

import 'package:leader_school/controllers/center/center_student_controller.dart';
import 'package:leader_school/services/get_helper.dart';

import '../../controllers/center/attendance_controller.dart';
import '../../controllers/center/center_exam_controller.dart';
import '../../widgets/add_group_student.dart';

import 'center_exam_tab_screen.dart';
import 'group_attendence_view.dart'; // MUHIM: shu ham

/// Guruh ichidagi ekran — Davomat tabida ISTALGAN qatorni UZOQ BOSSANGIZ
/// tanlash rejimi yoqiladi (raqamli doira ✓ belgiga aylanadi). Shu
/// holatda XOHLAGAN qadar qo'shimcha o'quvchini oddiy bosib qo'shish/
/// olib tashlash mumkin. Tezkor tugmalar ("Hammasini tanlash",
/// "Kelmaganlarni tanlash") ham mavjud — ular qo'lda tanlovga QO'SHILADI,
/// almashtirmaydi. Pastda "SMS yuborish (N)" tugmasi bosilsa — SMS turi
/// (Davomat/Shaxsiy) tanlanadi, so'ng tanlangan o'quvchilarga yuboriladi.
///
/// YANGI:
///   1. Orqaga qaytishda (AppBar'dagi orqaga tugmasi HAM, qurilmaning
///      o'zidagi tizim orqaga tugmasi/harakati HAM) — agar saqlanmagan
///      davomat o'zgarishlari bo'lsa, AVTOMATIK saqlanadi, keyin
///      chiqiladi. Endi "Saqlash"ni bosishni unutish muammo emas.
///   2. AppBar ostida — kalendar belgisi (istalgan sanani tanlash) va
///      chap/o'ng strelkalar (oldingi/keyingi kunga o'tish) qo'shildi.
///      Sana almashtirilganda ham, joriy sanadagi o'zgarishlar avval
///      avtomatik saqlanadi.
///   3. YANGI (INGLIZ TILI GURUHLARI UCHUN QO'SHIMCHA TAB'LAR,
///      TUZATILDI): agar shu guruh aynan "Ingliz tili" faniga
///      tegishli bo'lsa (fan qo'shish/tahrirlash ekranida admin
///      belgilaydigan 'isEnglish' bayrog'i orqali — 'center_subjects'
///      hujjatida tekshiriladi), TabBar'da "Davomat" va
///      "Imtihonlar"dan TASHQARI яна ikkita tab chiqadi: "Daily Task"
///      va "IELTS/CEFR". Boshqa har qanday fan uchun hech narsa
///      o'zgarmaydi — faqat 2 ta tab qoladi. MUHIM (TUZATILDI): avval
///      TabController "2 tadan 4 taga almashtirilardi" — bu Flutter'da
///      "Controller's length does not match tabs count" xatosiga
///      olib kelgan. ENDI ekran fan turini ANIQLAMAGUNCHA (odatda bir
///      necha yuz millisekund) oddiy "Yuklanmoqda" ekrani ko'rsatadi,
///      so'ng TabController TO'G'RI uzunlik bilan BIR MARTA yaratiladi
///      va boshqa hech qachon almashtirilmaydi — shu bilan bu xato
///      sinfi butunlay yo'q qilingan. HOZIRCHA ikkita yangi tab ICHIDA
///      faqat "Tez orada qo'shiladi" degan PLACEHOLDER bor.
class GroupDetailView extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String subjectId;

  const GroupDetailView({super.key, required this.groupId, required this.groupName, required this.subjectId});

  @override
  State<GroupDetailView> createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends State<GroupDetailView> with SingleTickerProviderStateMixin {
  // YANGI (TUZATILDI): endi nullable — fan turi ANIQLANGUNCHA
  // TabController umuman yaratilmaydi (shu bilan "length mismatch"
  // xatosi butunlay oldini olinadi). build() shu vaqt ichida oddiy
  // "Yuklanmoqda" ekranini ko'rsatadi.
  TabController? _tabController;
  late GroupStudentsController _studentsController;
  late CenterExamController _examController;
  late CenterSmsService _smsService;
  int _currentTabIndex = 0;

  // YANGI (INGLIZ TILI GURUHLARI UCHUN): true bo'lsa, TabBar 4 ta tab
  // (Davomat, Imtihonlar, Daily Task, IELTS/CEFR) bilan yaratiladi;
  // aks holda 2 ta (Davomat, Imtihonlar). Bu qiymat TabController
  // yaratilishidan OLDIN, _checkIfEnglishSubject() ichida bir marta
  // aniqlanadi va keyin o'zgarmaydi.
  bool _isEnglishSubject = false;

  // YANGI (TUZATILDI): fan turi (Ingliz tili yoki yo'q) hali
  // Firestore'dan tekshirilayotgan bo'lsa true — shu vaqtda TabBar/
  // TabBarView umuman qurilmaydi, oddiy loader ko'rsatiladi.
  bool _isLoadingSubjectCheck = true;

  @override
  void initState() {
    super.initState();

    _studentsController = putOnce(
          () => GroupStudentsController(groupId: widget.groupId, subjectId: widget.subjectId),
      tag: 'group_${widget.groupId}',
    );
    _examController = putOnce(
          () => CenterExamController(groupId: widget.groupId),
      tag: 'center_exam_${widget.groupId}',
    );
    _smsService = putOnce(
          () => CenterSmsService(),
      tag: 'center_sms_${widget.groupId}',
    );

    // YANGI (INGLIZ TILI GURUHLARI UCHUN, TUZATILDI): fan nomini/
    // bayrog'ini tekshirib, natijaga qarab TabController'ni TO'G'RI
    // uzunlik bilan BIR MARTA yaratadi (build() shu tugaguncha loader
    // ko'rsatadi).
    _checkIfEnglishSubject();
  }

  void _onTabControllerTick() {
    setState(() => _currentTabIndex = _tabController!.index);
  }

  // YANGI (ENG ISHONCHLI USUL): endi fan nomini "taxmin qilish"
  // (lotin/kirill/qisqartma farqlari) o'rniga, fan qo'shish/tahrirlash
  // ekranida ADMIN o'zi belgilaydigan ANIQ 'isEnglish' bayrog'iga
  // qaraymiz — bu qanday nomlanishidan qat'i nazar ISHONCHLI ishlaydi.
  // Agar hali biror fan hujjatida bu bayroq YO'Q bo'lsa (masalan eski
  // fanlar hali yangilanmagan), ehtiyot chorasi sifatida eski nom
  // bo'yicha tekshiruvga (ingliz/инглиз/english) qaytamiz.
  //
  // YANGI (TUZATILDI — "Controller's length... does not match" xatosi
  // uchun): avval bu funksiya tugagach TabController'ni "2 tadan 4
  // taga almashtirar" edi — bu Flutter'ning ichki TabBar assertion'i
  // bilan to'qnashib, "Controller's length property (2) does not
  // match the number of tabs (4)" xatosini chiqargan. ENDI
  // TabController BU FUNKSIYA TUGAGANDAN KEYIN, natijaga qarab TO'G'RI
  // uzunlik bilan BIR MARTA yaratiladi — boshqa hech qachon
  // almashtirilmaydi.
  Future<void> _checkIfEnglishSubject() async {
    bool isEnglish = false;
    try {
      final doc = await FirebaseFirestore.instance.collection('center_subjects').doc(widget.subjectId).get();
      final data = doc.data();
      final explicitFlag = data?['isEnglish'];
      if (explicitFlag is bool) {
        isEnglish = explicitFlag;
      } else {
        final rawName = (data?['name'] ?? '').toString().toLowerCase();
        isEnglish = rawName.contains('ingliz') || rawName.contains('инглиз') || rawName.contains('english');
      }
      debugPrint("[GroupDetailView] subjectId=${widget.subjectId} isEnglish=$isEnglish (bayroq: $explicitFlag)");
    } catch (e) {
      debugPrint("Fan turini tekshirishda xato: $e");
    }

    if (!mounted) return;
    setState(() {
      _isEnglishSubject = isEnglish;
      _tabController = TabController(length: _isEnglishSubject ? 4 : 2, vsync: this);
      _tabController!.addListener(_onTabControllerTick);
      _isLoadingSubjectCheck = false;
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    Get.delete<GroupStudentsController>(tag: 'group_${widget.groupId}');
    Get.delete<CenterExamController>(tag: 'center_exam_${widget.groupId}');
    Get.delete<CenterSmsService>(tag: 'center_sms_${widget.groupId}');
    super.dispose();
  }

  List<String> get _absentStudentIds {
    return _studentsController.classStudents
        .where((s) => _studentsController.attendanceMap[s['id']] == false)
        .map((s) => s['id'] as String)
        .toList();
  }

  // =======================================================================
  // YANGI: orqaga chiqishdan OLDIN — saqlanmagan davomat o'zgarishlari
  // bo'lsa, AVTOMATIK saqlaydi. Bu funksiya HAM AppBar'dagi orqaga
  // tugmasi, HAM qurilmaning tizim orqaga tugmasi/harakati uchun
  // BIR XIL ishlatiladi.
  // =======================================================================
  Future<void> _saveIfNeededAndPop() async {
    if (_studentsController.hasUnsavedChanges) {
      await _studentsController.saveAttendance();
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Get.back();
    }
  }

  void _onLongPressStudent(Map<String, dynamic> student) {
    _smsService.enterSelectionMode(student['id']);
    _showSmsTypeSheet();
  }

  void _showSmsTypeSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text("SMS turini tanlang", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text("${_smsService.selectedIds.length} ta o'quvchi tanlandi", style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.fact_check_rounded, color: Color(0xFF3B82F6)),
              ),
              title: const Text("Davomat haqida SMS", style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text("Tayyor shablon bo'yicha", style: TextStyle(fontSize: 12)),
              onTap: () async {
                Get.back();
                await Future.delayed(const Duration(milliseconds: 150));
                _pickAudienceForAttendance();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.edit_note_rounded, color: Color(0xFF10B981)),
              ),
              title: const Text("Shaxsiy SMS", style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text("O'zingiz matn yozasiz", style: TextStyle(fontSize: 12)),
              onTap: () async {
                Get.back();
                await Future.delayed(const Duration(milliseconds: 150));
                _showCustomSmsDialog();
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _pickAudienceForAttendance() {
    final all = _studentsController.classStudents;
    final absentIds = _absentStudentIds;
    final int currentlyChecked = _smsService.selectedIds.length;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text("Kimlarga yuborilsin?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text(
              "Har bir o'quvchiga o'z holatiga mos matn (kelgan/kelmagan) ketadi.",
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.checklist_rounded, color: Color(0xFF8B5CF6)),
              ),
              title: Text("Faqat tanlanganlarga ($currentlyChecked)", style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text("Belgilagan (✓) o'quvchilaringiz", style: TextStyle(fontSize: 11.5)),
              onTap: () async {
                Get.back();
                await Future.delayed(const Duration(milliseconds: 150));
                _confirmAndSendAttendanceSms();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: absentIds.isNotEmpty,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.person_off_rounded, color: Color(0xFFDC2626)),
              ),
              title: Text(
                "Faqat kelmaganlarga (${absentIds.length})",
                style: TextStyle(fontWeight: FontWeight.w600, color: absentIds.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A)),
              ),
              subtitle: absentIds.isEmpty ? const Text("Bugun hali belgilanmagan yoki hammasi keldi", style: TextStyle(fontSize: 11.5)) : null,
              onTap: absentIds.isEmpty
                  ? null
                  : () async {
                Get.back();
                await Future.delayed(const Duration(milliseconds: 150));
                _smsService.selectedIds.value = absentIds.toSet();
                _confirmAndSendAttendanceSms();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.groups_rounded, color: Color(0xFF10B981)),
              ),
              title: Text("Hammaga (${all.length})", style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Get.back();
                await Future.delayed(const Duration(milliseconds: 150));
                _smsService.selectedIds.value = all.map((s) => s['id'] as String).toSet();
                _confirmAndSendAttendanceSms();
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _confirmAndSendAttendanceSms() async {
    final selectedCount = _smsService.selectedIds.length;

    final confirmed = await Get.dialog<bool>(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, 12))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFF10B981).withOpacity(0.15), const Color(0xFF10B981).withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF10B981), size: 32),
              ),
              const SizedBox(height: 20),
              const Text("SMS yuborish", style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                  children: [
                    const TextSpan(text: "Tanlangan "),
                    TextSpan(text: "$selectedCount ta o'quvchi", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    const TextSpan(text: "ning ota-onasiga davomat haqida SMS yuboriladi. Davom etasizmi?"),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE2E8F0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: () => Get.back(result: false),
                        child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                        onPressed: () => Get.back(result: true),
                        icon: const Icon(Icons.send_rounded, size: 17, color: Colors.white),
                        label: const Text("Yuborish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _smsService.sendAttendanceSms(
        allStudents: _studentsController.classStudents,
        attendanceMap: _studentsController.attendanceMap,
        groupName: widget.groupName,
      );
    }
  }

  void _showCustomSmsDialog() {
    final textController = TextEditingController();

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Text("Shaxsiy SMS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)))),
                ],
              ),
              const SizedBox(height: 6),
              Obx(() => Text(
                "${_smsService.selectedIds.length} ta ota-onaga yuboriladi. {ism} yozsangiz, har birining ismi bilan almashadi.",
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
              )),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 5,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Masalan: Assalomu alaykum, {ism}ning ertagi darsi bekor qilindi.",
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE2E8F0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: () => Get.back(),
                        child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                        onPressed: () {
                          final text = textController.text.trim();
                          if (text.isEmpty) {
                            Get.snackbar("Diqqat", "SMS matnini kiriting", backgroundColor: Colors.orange, colorText: Colors.white);
                            return;
                          }
                          Get.back();
                          _smsService.sendCustomSms(allStudents: _studentsController.classStudents, customText: text);
                        },
                        icon: const Icon(Icons.send_rounded, size: 17, color: Colors.white),
                        label: const Text("Yuborish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // YANGI: kalendar orqali ISTALGAN sanani tanlash.
  Future<void> _pickAttendanceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _studentsController.selectedDate.value,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      await _studentsController.changeDate(picked);
    }
  }

  // YANGI: AppBar ostidagi sana navigatsiyasi qatori — kalendar belgisi
  // + chap/o'ng strelkalar. Faqat "Davomat" tabida (tanlash rejimida
  // EMASKAN) ko'rinadi.
  // YANGI: AppBar sarlavhasi OSTIDA (bir xil title qatorida), ixcham
  // ko'rinishda — kalendar belgisi + chap/o'ng strelkalar.
  Widget _buildCompactDateNavRow() {
    return Obx(() {
      final date = _studentsController.selectedDate.value;
      final bool isToday = _studentsController.isViewingToday;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 24, color: Color(0xFF64748B)),
            onPressed: () => _studentsController.goToPreviousDay(),
            tooltip: "Oldingi kun",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _pickAttendanceDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(
                    isToday ? "Bugun" : DateFormat('dd.MM.yyyy').format(date),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, size: 24, color: isToday ? const Color(0xFFE2E8F0) : const Color(0xFF64748B)),
            onPressed: isToday ? null : () => _studentsController.goToNextDay(),
            tooltip: "Keyingi kun",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          ),
          const SizedBox(width: 6),
        ],
      );
    });
  }

  // YANGI (INGLIZ TILI GURUHLARI UCHUN, PLACEHOLDER): "Daily Task" va
  // "IELTS/CEFR" tab'larining HOZIRGI tarkibi — faqat "Tez orada
  // qo'shiladi" ko'rinishi. Haqiqiy tarkib keyinroq shu ikkita
  // metodga (yoki alohida fayllarga) qo'shiladi.
  Widget _buildComingSoonTab({required IconData icon, required String title, required String subtitle}) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: const Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Color(0xFF334155), fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTaskTab() {
    return _buildComingSoonTab(icon: Icons.today_rounded, title: "Daily Task", subtitle: "Tez orada qo'shiladi");
  }

  Widget _buildIeltsCefrTab() {
    return _buildComingSoonTab(icon: Icons.school_rounded, title: "IELTS/CEFR", subtitle: "Tez orada qo'shiladi");
  }

  @override
  Widget build(BuildContext context) {
    // YANGI (TUZATILDI): fan turi (Ingliz tili yoki yo'q) hali
    // tekshirilayotgan bo'lsa — TabBar/TabController UMUMAN
    // qurilmaydi (chunki hali qaysi uzunlikda kerakligi noma'lum).
    // Bu tekshiruv odatda bir necha yuz millisekund davom etadi.
    if (_isLoadingSubjectCheck || _tabController == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          title: Text(widget.groupName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      );
    }

    // YANGI: bundan keyingi butun build() shu YAGONA, TO'G'RI
    // uzunlikdagi TabController orqali ishlaydi — u boshqa hech
    // qachon almashtirilmaydi.
    final TabController tabController = _tabController!;

    // YANGI: qurilmaning tizim ORQAGA tugmasi/harakati ham AVVAL
    // saqlaydi, keyin chiqadi — AppBar'dagi orqaga tugmasi bilan BIR
    // XIL xatti-harakat.
    return WillPopScope(
      onWillPop: () async {
        if (_studentsController.hasUnsavedChanges) {
          await _studentsController.saveAttendance();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Obx(() => _smsService.selectionMode.value
              ? IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)), onPressed: _smsService.cancel)
          // YANGI: oddiy BackButton o'rniga — avval saqlab, keyin chiqadigan tugma.
              : IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
            onPressed: _saveIfNeededAndPop,
          )),
          title: Obx(() => Text(
            _smsService.selectionMode.value ? "${_smsService.selectedIds.length} ta tanlandi" : widget.groupName,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          )),
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          // YANGI (INGLIZ TILI GURUHLARI UCHUN): agar _isEnglishSubject
          // true bo'lsa TabBar 4 ta tab bilan, isScrollable: true —
          // aks holda odatdagidek 2 ta tab, isScrollable: false.
          bottom: TabBar(
            controller: tabController,
            isScrollable: _isEnglishSubject,
            labelColor: const Color(0xFF10B981),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF10B981),
            indicatorWeight: 3,
            tabs: [
              const Tab(text: "Davomat"),
              const Tab(text: "Imtihonlar"),
              if (_isEnglishSubject) const Tab(text: "Daily Task"),
              if (_isEnglishSubject) const Tab(text: "IELTS/CEFR"),
            ],
          ),
          // YANGI: kalendar + strelkalar endi AppBar'ning ACTION
          // qismida (o'ng tomonda) — faqat Davomat tabida va tanlash
          // rejimida bo'lmaganda.
          actions: [
            Obx(() {
              if (_smsService.selectionMode.value) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: "Kelmaganlarni tanlash",
                      icon: const Icon(Icons.person_off_rounded, color: Color(0xFFDC2626), size: 21),
                      onPressed: () => _smsService.selectAbsent(_absentStudentIds),
                    ),
                    IconButton(
                      tooltip: "Hammasini tanlash",
                      icon: const Icon(Icons.done_all_rounded, color: Color(0xFF10B981)),
                      onPressed: () => _smsService.selectAll(_studentsController.classStudents.map((s) => s['id'] as String).toList()),
                    ),
                  ],
                );
              }
              if (_currentTabIndex == 0) {
                return _buildCompactDateNavRow();
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(width: 4),
          ],
        ),
        floatingActionButton: Obx(() {
          if (_currentTabIndex != 0 || _smsService.selectionMode.value) return const SizedBox.shrink();
          return FloatingActionButton(
            backgroundColor: const Color(0xFF10B981),
            onPressed: () => showAddGroupStudentSheet(context, _studentsController),
            child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
          );
        }),
        bottomNavigationBar: Obx(() {
          final bool visible = _currentTabIndex == 0 && _smsService.selectionMode.value && _smsService.selectedIds.isNotEmpty;

          return AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: !visible
                ? const SizedBox(width: double.infinity, height: 0)
                : Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -6))]),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: const StadiumBorder(), elevation: 0),
                  onPressed: _smsService.isSending.value ? null : _showSmsTypeSheet,
                  icon: _smsService.isSending.value
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sms_rounded, color: Colors.white),
                  label: Text(
                    _smsService.isSending.value ? "Yuborilmoqda..." : "SMS yuborish (${_smsService.selectedIds.length})",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5),
                  ),
                ),
              ),
            ),
          );
        }),
        // YANGI: saqlash paytida (sana almashtirish yoki orqaga
        // chiqishda avtomatik saqlanganda) ekran "qotib qolgandek"
        // ko'rinmasligi uchun — markazda aniq, chiroyli loader
        // ko'rsatiladi. isSaving allaqachon controller'da mavjud edi.
        body: Stack(
          children: [
            TabBarView(
              controller: tabController,
              children: [
                GroupAttendanceTabScreen(
                  controller: _studentsController,
                  groupId: widget.groupId,
                  subjectId: widget.subjectId,
                  selectionController: _smsService,
                  onLongPressStudent: _onLongPressStudent,
                ),
                CenterExamsTabScreen(
                  examController: _examController,
                  students: _studentsController.classStudents,
                ),
                // YANGI (INGLIZ TILI GURUHLARI UCHUN, PLACEHOLDER):
                // TabController.length bilan bir xil sonda bo'lishi
                // uchun _isEnglishSubject bo'lsagina qo'shiladi.
                if (_isEnglishSubject) _buildDailyTaskTab(),
                if (_isEnglishSubject) _buildIeltsCefrTab(),
              ],
            ),
            Obx(() {
              if (!_studentsController.isSaving.value) return const SizedBox.shrink();
              return Container(
                color: Colors.black.withOpacity(0.25),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 32,
                          offset: const Offset(0, 10),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            color: Color(0xFFF59E0B), // Amber rang
                          ),
                        ),
                        SizedBox(height: 18),
                        Text(
                          "⏳ Biroz kuting... 😊",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            fontSize: 17,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Hammasi zo'r bo'ladi! ✨",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "🌞 Yaxshi narsalar vaqt talab qiladi",
                          style: TextStyle(
                            fontWeight: FontWeight.w300,
                            color: Color(0xFF94A3B8),
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}