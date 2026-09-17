import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../controllers/school_student_profil/school_student.dart';
import '../../../controllers/school_student_profil/student_payment_controller.dart';
import '../../../services/get_helper.dart';
import '../../../services/student_photo_service.dart';
import '../../../widgets/add_payment_dialog.dart';
import '../../../widgets/payment_success_dialog.dart';
import '../../../widgets/student_groups_edit_dialog.dart'; // MUHIM: sizning haqiqiy yo'lingizga moslang — endi to'liq ekran (showStudentGroupsEditScreen)

// =========================================================================
// YANGI DIZAYN: profilga kirilganda 4 ta NAVIGATSION KARTA ko'rinadi
// (Shaxsiy ma'lumotlar / Davomat / To'lovlar / Imtihonlar) — har biri
// qisqa oldindan ko'rish (preview) bilan. Kartaga bosilsa — o'sha
// bo'limning TO'LIQ tarkibi ALOHIDA ekranda ochiladi.
// =========================================================================

class StudentProfileView extends StatefulWidget {
  final String studentId;
  final String subjectId;
  final String studentName;
  final bool fromCenterContext;
  final String? centerSubjectId;

  const StudentProfileView({
    super.key,
    required this.studentId,
    required this.subjectId,
    required this.studentName,
    this.fromCenterContext = false,
    this.centerSubjectId,
  });

  @override
  State<StudentProfileView> createState() => _StudentProfileViewState();
}

class _ExamResultEntry {
  final String examName;
  final String type;
  final int questionCount;
  final dynamic score;
  final DateTime? date;
  final String sourceLabel;

  _ExamResultEntry({
    required this.examName,
    required this.type,
    required this.questionCount,
    required this.score,
    required this.date,
    required this.sourceLabel,
  });

  String get displayScore {
    if (score is num) {
      return questionCount > 0 ? "${score.toString()} / $questionCount" : score.toString();
    }
    if (score is Map) {
      final map = score as Map;
      final val = map['score'] ?? map['ball'] ?? map['correct'] ?? map['correctCount'];
      if (val != null) return questionCount > 0 ? "$val / $questionCount" : "$val";
    }
    return "—";
  }
}

class _StudentProfileViewState extends State<StudentProfileView> {
  late final StudentProfileController _controller;
  late final StudentPaymentController _paymentController;

  String? _photoUrl;
  bool _photoLoading = true;
  bool _photoUploading = false;
  bool _isRefreshing = false;

  bool _isLoadingExams = true;
  List<_ExamResultEntry> _examResults = [];
  bool _attendanceSummaryRequested = false;

  // YANGI: AppBar sarlavhasi endi shu o'zgaruvchidan o'qiladi
  // (widget.studentName EMAS) — shunda "Shaxsiy ma'lumotlar" ekranida
  // ism-familiya tahrirlab saqlanganda, asosiy profil sahifasiga
  // qaytilganda TEPADAGI sarlavha ham DARHOL yangilanadi.
  late String _currentName;

  @override
  void initState() {
    super.initState();
    _currentName = widget.studentName;

    _controller = putOnce(
          () => StudentProfileController(studentId: widget.studentId, subjectId: widget.subjectId),
      tag: widget.studentId,
    );
    _paymentController = putOnce(
          () => StudentPaymentController(studentId: widget.studentId),
      tag: widget.studentId,
    );

    _loadExamResults();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final url = await StudentPhotoService.getPhotoUrl(widget.studentId);
    if (!mounted) return;
    setState(() {
      _photoUrl = url;
      _photoLoading = false;
    });
  }

  Future<void> _loadExamResults() async {
    setState(() => _isLoadingExams = true);
    try {
      final db = FirebaseFirestore.instance;
      final List<_ExamResultEntry> results = [];

      final studentDoc = await db.collection('students').doc(widget.studentId).get();
      final studentData = studentDoc.data() ?? {};
      final String? classId = studentData['classId'] as String?;
      final List<String> centerGroupIds = List<String>.from(studentData['centerGroupIds'] ?? []);

      if (classId != null && classId.isNotEmpty) {
        final examsSnap = await db.collection('exams').where('classId', isEqualTo: classId).get();
        for (final doc in examsSnap.docs) {
          final data = doc.data();
          if (data['isDeleted'] == true) continue;
          final scores = Map<String, dynamic>.from(data['scores'] ?? {});
          if (!scores.containsKey(widget.studentId)) continue;
          results.add(_ExamResultEntry(
            examName: (data['name'] ?? 'Nomsiz imtihon').toString(),
            type: (data['type'] ?? '').toString(),
            questionCount: (data['questionCount'] as num?)?.toInt() ?? 0,
            score: scores[widget.studentId],
            date: (data['createdAt'] as Timestamp?)?.toDate(),
            sourceLabel: "Maktab",
          ));
        }
      }

      for (final groupId in centerGroupIds) {
        final examsSnap = await db
            .collection('center_exams')
            .where('groupId', isEqualTo: groupId)
            .where('isDeleted', isEqualTo: false)
            .get();
        for (final doc in examsSnap.docs) {
          final data = doc.data();
          final scores = Map<String, dynamic>.from(data['scores'] ?? {});
          if (!scores.containsKey(widget.studentId)) continue;
          final groupInfo = _controller.centerGroupNames.firstWhereOrNull((g) => g['id'] == groupId);
          results.add(_ExamResultEntry(
            examName: (data['name'] ?? 'Nomsiz imtihon').toString(),
            type: (data['type'] ?? '').toString(),
            questionCount: (data['questionCount'] as num?)?.toInt() ?? 0,
            score: scores[widget.studentId],
            date: (data['createdAt'] as Timestamp?)?.toDate(),
            sourceLabel: groupInfo?['name'] ?? "Guruh",
          ));
        }
      }

      results.sort((a, b) {
        if (a.date == null || b.date == null) return 0;
        return b.date!.compareTo(a.date!);
      });

      if (!mounted) return;
      setState(() {
        _examResults = results;
        _isLoadingExams = false;
      });
    } catch (e) {
      debugPrint("Imtihon natijalarini yuklashda xato: $e");
      if (mounted) setState(() => _isLoadingExams = false);
    }
  }

  Future<void> _refreshAll() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final results = await Future.wait([
        StudentPhotoService.refreshPhotoUrl(widget.studentId),
        _paymentController.refresh().then((_) => null),
        _controller.refresh().then((_) => null),
        _controller.loadFullAttendanceSummary().then((_) => null),
        _loadExamResults().then((_) => null),
      ]);
      if (!mounted) return;
      setState(() => _photoUrl = results[0] as String?);
      Get.snackbar("Yangilandi", "Ma'lumotlar serverdan qayta yuklandi",
          backgroundColor: const Color(0xFF10B981), colorText: Colors.white, snackPosition: SnackPosition.TOP);
    } catch (e) {
      Get.snackbar("Xatolik", "Yangilashda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _photoUploading = true);
    try {
      final url = await StudentPhotoService.pickAndUploadPhoto(widget.studentId, source: source);
      if (url != null && mounted) {
        setState(() => _photoUrl = url);
        Get.snackbar("Saqlandi", "Rasm yangilandi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar("Xatolik", "Rasm yuklashda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  void _openFullscreenPhoto() {
    if (_photoUrl == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _FullscreenPhotoView(photoUrl: _photoUrl!, heroTag: 'student_photo_${widget.studentId}'),
          );
        },
      ),
    );
  }

  void _showPhotoSourceSheet() {
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
            const Text("O'quvchi rasmi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF3B82F6)),
              ),
              title: const Text("Kameradan olish"),
              onTap: () {
                Get.back();
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
              ),
              title: const Text("Galereyadan tanlash"),
              onTap: () {
                Get.back();
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  void dispose() {
    Get.delete<StudentProfileController>(tag: widget.studentId);
    Get.delete<StudentPaymentController>(tag: widget.studentId);
    super.dispose();
  }

  Widget _navCard({required IconData icon, required Color color, required String title, required Widget subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEEF2F6)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    subtitle,
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
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
        // YANGI: _currentName'dan o'qiydi (widget.studentName emas).
        title: Text(_currentName, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF10B981)))
                : const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _isRefreshing ? null : _refreshAll,
            tooltip: "Yangilash",
          ),
        ],
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!_attendanceSummaryRequested) {
          _attendanceSummaryRequested = true;
          _controller.loadFullAttendanceSummary();
        }

        return RefreshIndicator(
          color: const Color(0xFF10B981),
          onRefresh: _refreshAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _photoUrl != null ? _openFullscreenPhoto : (_photoUploading ? null : _showPhotoSourceSheet),
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF10B981), width: 2.5), color: const Color(0xFFF1F5F9)),
                          child: ClipOval(
                            child: (_photoLoading || _photoUploading)
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                                : (_photoUrl != null
                                ? Hero(
                              tag: 'student_photo_${widget.studentId}',
                              child: Image.network(
                                _photoUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981))),
                                errorBuilder: (context, error, stack) => const Icon(Icons.person_rounded, size: 44, color: Color(0xFF94A3B8)),
                              ),
                            )
                                : const Icon(Icons.person_rounded, size: 44, color: Color(0xFF94A3B8))),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _photoUploading ? null : _showPhotoSourceSheet,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _navCard(
                  icon: Icons.badge_rounded,
                  color: const Color(0xFF3B82F6),
                  title: "Shaxsiy ma'lumotlar",
                  subtitle: const Text("Ism, telefon", style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                  onTap: () => Get.to(() => _PersonalInfoScreen(
                    controller: _controller,
                    studentId: widget.studentId,
                    studentName: _currentName,
                    onSaved: (newName) => setState(() => _currentName = newName),
                  )),
                ),

                // YANGI: "Sinf va guruhlar" endi ALOHIDA, TOP-LEVEL
                // navigatsion karta — avval "Shaxsiy ma'lumotlar" ichiga
                // kirib, keyin "O'zgartirish"ni topish kerak edi, bu
                // noqulay edi.
                _navCard(
                  icon: Icons.groups_rounded,
                  color: const Color(0xFF10B981),
                  title: "Sinf va guruhlar",
                  subtitle: Obx(() {
                    if (_controller.isLoadingGroupNames.value) {
                      return const Text("Yuklanmoqda...", style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)));
                    }
                    final parts = <String>[];
                    if (_controller.hasSchoolClass.value) parts.add("Maktab");
                    final groupCount = _controller.centerGroupNames.length;
                    if (groupCount > 0) parts.add("$groupCount ta guruh");
                    if (parts.isEmpty) return const Text("Biriktirilmagan", style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)));
                    return Text(parts.join(' · '), style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)));
                  }),
                  onTap: () => showStudentGroupsEditScreen(
                    currentGroupIds: _controller.centerGroupIds,
                    currentClassId: _controller.classId,
                    onSave: (newIds, subjMap, newClassId) => _controller.updateGroupMembership(
                      newGroupIds: newIds,
                      subjectIdByGroupId: subjMap,
                      newClassId: newClassId,
                    ),
                  ),
                ),

                _navCard(
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFF059669),
                  title: "Davomat",
                  subtitle: Obx(() {
                    if (_controller.isLoadingAttendanceSummary.value) {
                      return const Text("Yuklanmoqda...", style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)));
                    }
                    final schoolPercent = _controller.schoolAttendancePercent.value;
                    final centerCount = _controller.centerAttendanceByGroup.length;
                    if (schoolPercent == null && centerCount == 0) {
                      return const Text("Ma'lumot yo'q", style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)));
                    }
                    final parts = <String>[];
                    if (schoolPercent != null) parts.add("Maktab: ${schoolPercent.toStringAsFixed(0)}%");
                    if (centerCount > 0) parts.add("$centerCount ta guruh");
                    return Text(parts.join(' · '), style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)));
                  }),
                  onTap: () => Get.to(() => _AttendanceScreen(controller: _controller, studentName: _currentName)),
                ),

                _navCard(
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF10B981),
                  title: "To'lovlar",
                  subtitle: Obx(() {
                    if (_controller.isLoadingPermissions.value) {
                      return const Text("Yuklanmoqda...", style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)));
                    }
                    if (!_controller.canViewPayments.value) {
                      return const Text("Ruxsat yo'q", style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)));
                    }
                    if (_paymentController.isLoading.value) {
                      return const Text("Yuklanmoqda...", style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)));
                    }
                    final currencyFormat = NumberFormat("#,###", "uz");
                    return Text("Shu oy: ${currencyFormat.format(_paymentController.totalPaidThisMonth)} so'm", style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)));
                  }),
                  onTap: () => Get.to(() => _PaymentsScreen(
                    paymentController: _paymentController,
                    studentName: _currentName,
                    parentPhone: _controller.parentPhoneController.text,
                    hasSchoolClass: _controller.hasSchoolClass.value,
                    fromCenterContext: widget.fromCenterContext,
                    centerSubjectId: widget.centerSubjectId,
                    centerSubjectJoinedAt: widget.centerSubjectId != null ? _controller.subjectJoinedAt(widget.centerSubjectId!) : null,
                    canViewPayments: _controller.canViewPayments.value,
                    canEditPayments: _controller.canEditPayments.value,
                    isLoadingPermissions: _controller.isLoadingPermissions.value,
                  )),
                ),

                _navCard(
                  icon: Icons.assignment_turned_in_rounded,
                  color: const Color(0xFF8B5CF6),
                  title: "Imtihon natijalari",
                  subtitle: _isLoadingExams
                      ? const Text("Yuklanmoqda...", style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)))
                      : Text(_examResults.isEmpty ? "Hali natija yo'q" : "${_examResults.length} ta natija", style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                  onTap: () => Get.to(() => _ExamResultsScreen(studentName: _currentName, isLoading: _isLoadingExams, results: _examResults)),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// =========================================================================
// EKRAN 1: SHAXSIY MA'LUMOTLAR — endi StatefulWidget (Saqlash/O'chirish
// tugmalarida loader ko'rsatish uchun mahalliy holat kerak).
// =========================================================================
class _PersonalInfoScreen extends StatefulWidget {
  final StudentProfileController controller;
  final String studentId;
  final String studentName;
  final void Function(String newName)? onSaved; // YANGI

  const _PersonalInfoScreen({
    required this.controller,
    required this.studentId,
    required this.studentName,
    this.onSaved,
  });

  @override
  State<_PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<_PersonalInfoScreen> {
  // YANGI: tugmalardagi loader holati.
  bool _isSaving = false;
  bool _isArchiving = false;

  static const List<Map<String, dynamic>> _archiveReasons = [
    {'key': 'graduated', 'label': "Bitirdi", 'icon': Icons.school_rounded},
    {'key': 'enrolled_elsewhere', 'label': "O'qishga kirdi", 'icon': Icons.emoji_events_rounded},
    {'key': 'expelled', 'label': "Haydaldi", 'icon': Icons.gavel_rounded},
    {'key': 'financial', 'label': "Moliyaviy sharoitlar", 'icon': Icons.payments_rounded},
    {'key': 'family', 'label': "Oilaviy sharoit", 'icon': Icons.home_rounded},
  ];

  // YANGI: Saqlash tugmasi — endi loader bilan.
  Future<void> _handleSave() async {
    final firstName = widget.controller.firstNameController.text.trim();
    final lastName = widget.controller.lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      Get.snackbar("Diqqat", "Ism va familiyani kiriting!", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.controller.updateStudentProfile();
      // YANGI: muvaffaqiyatli saqlangach, asosiy sahifadagi TEPADAGI
      // sarlavhani yangilash uchun ota-widget'ga xabar beramiz.
      widget.onSaved?.call("$firstName $lastName");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showArchiveReasonSheet(BuildContext context) {
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.person_remove_outlined, color: Color(0xFFDC2626), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text("O'quvchini o'chirish sababi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)))),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "O'quvchi barcha sinf/guruhlardan chiqariladi, lekin ma'lumotlari (to'lovlar, davomat) arxivda saqlanib qoladi.",
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
            ),
            const SizedBox(height: 16),
            ..._archiveReasons.map((r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                child: Icon(r['icon'] as IconData, color: const Color(0xFF64748B)),
              ),
              title: Text(r['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              onTap: () {
                Get.back();
                _confirmAndArchive(context, r['key'] as String, r['label'] as String);
              },
            )),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  // YANGI: endi loader bilan (_isArchiving).
  Future<void> _confirmAndArchive(BuildContext context, String reasonKey, String reasonLabel) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Tasdiqlaysizmi?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text(
          "\"${widget.studentName}\" o'quvchisi \"$reasonLabel\" sababi bilan barcha guruh/sinflardan chiqariladi. Davom etasizmi?",
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text("Bekor qilish")),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text("Ha, o'chirish", style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isArchiving = true);
    final ok = await widget.controller.archiveStudent(reasonKey);
    if (!mounted) return;

    if (ok) {
      Get.snackbar("Bajarildi", "O'quvchi arxivlandi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      Get.back();
      Get.back();
    } else {
      setState(() => _isArchiving = false);
      Get.snackbar("Xatolik", "Arxivlashda xato yuz berdi", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    var phoneFormatter = MaskTextInputFormatter(mask: '+998 (##) ###-##-##', filter: {"#": RegExp(r'[0-9]')}, type: MaskAutoCompletionType.lazy);
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text("Shaxsiy ma'lumotlar", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 17)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Ma'lumotlarni tahrirlash", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: controller.firstNameController, decoration: _inputDecoration("Ismi"))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: controller.lastNameController, decoration: _inputDecoration("Familiyasi"))),
                ],
              ),
              const SizedBox(height: 16),
              TextField(controller: controller.phoneController, keyboardType: TextInputType.phone, inputFormatters: [phoneFormatter], decoration: _inputDecoration("O'quvchi telefoni")),
              const SizedBox(height: 16),
              TextField(controller: controller.parentPhoneController, keyboardType: TextInputType.phone, inputFormatters: [phoneFormatter], decoration: _inputDecoration("Ota-ona telefoni")),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Obx(() => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Imtiyozli (To'lovdan ozod)", style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF0F172A), fontSize: 14)),
                    Switch.adaptive(
                      value: controller.isPrivileged.value,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) => controller.isPrivileged.value = val,
                    ),
                  ],
                )),
              ),
              const SizedBox(height: 24),

              // YANGI: Saqlash tugmasi — loader bilan, jarayonda bosib
              // bo'lmaydi.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                  onPressed: (_isSaving || _isArchiving) ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text("O'zgarishlarni saqlash", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),

              // YANGI: O'chirish tugmasi — loader bilan, jarayonda
              // bosib bo'lmaydi.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFECACA)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: (_isSaving || _isArchiving) ? null : () => _showArchiveReasonSheet(context),
                  icon: _isArchiving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFFDC2626)))
                      : const Icon(Icons.person_remove_outlined, color: Color(0xFFDC2626), size: 20),
                  label: Text(_isArchiving ? "O'chirilmoqda..." : "O'quvchini o'chirish", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// YANGI: _AttendanceScreen — endi 2 ta TAB: "Maktab" va "Markaz".
//
//   - "Maktab" tabi: bu o'quvchining SINFIDA o'qitiladigan HAR BIR FAN
//     uchun ALOHIDA davomat foizi/kalendari ko'rsatiladi (avval faqat
//     profil qaysi fandan ochilgan bo'lsa, o'sha bitta fan ko'rinardi).
//   - "Markaz" tabi: avvalgi "Markaz guruhlari" chip+kalendar mantig'i,
//     o'zgarishsiz.
//
// MUHIM: "Maktab" tabidagi fan-bo'yicha ma'lumot BU EKRANNING O'ZIDA
// mahalliy yuklanadi (StudentProfileController'ga tegilmadi) — xuddi
// "Imtihon natijalari" bo'limi kabi.
// =========================================================================
class _AttendanceScreen extends StatefulWidget {
  final StudentProfileController controller;
  final String studentName;

  const _AttendanceScreen({required this.controller, required this.studentName});

  @override
  State<_AttendanceScreen> createState() => _AttendanceScreenState();
}

class _SchoolSubjectAttendance {
  final String subjectId;
  final String subjectName;
  final double? percent;
  final Map<String, bool> dayMap;

  _SchoolSubjectAttendance({
    required this.subjectId,
    required this.subjectName,
    required this.percent,
    required this.dayMap,
  });
}

class _AttendanceScreenState extends State<_AttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Markaz tabi uchun — qaysi guruh/manba tanlangan.
  String? _selectedCenterSource;

  // YANGI: Maktab tabi uchun — fanlar bo'yicha davomat.
  bool _isLoadingSchoolSubjects = true;
  List<_SchoolSubjectAttendance> _schoolSubjects = [];
  String? _selectedSchoolSubjectId;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _tabController = TabController(length: 2, vsync: this);
    _loadSchoolSubjectsAttendance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// YANGI: bu o'quvchining SINFIGA tegishli HAR BIR FAN uchun, oxirgi
  /// 60 kunlik davomatni alohida hisoblab chiqadi.
  Future<void> _loadSchoolSubjectsAttendance() async {
    final classId = widget.controller.classId;
    if (classId == null || classId.isEmpty) {
      if (mounted) setState(() => _isLoadingSchoolSubjects = false);
      return;
    }

    setState(() => _isLoadingSchoolSubjects = true);
    try {
      final db = FirebaseFirestore.instance;
      final cutoff = _dateKey(DateTime.now().subtract(const Duration(days: 60)));

      final subjectsSnap = await db.collection('subjects').where('classId', isEqualTo: classId).get();

      final List<_SchoolSubjectAttendance> results = [];
      for (final subjDoc in subjectsSnap.docs) {
        final subjName = (subjDoc.data()['name'] ?? 'Nomsiz fan').toString();

        final attSnap = await db
            .collection('attendance')
            .where('subjectId', isEqualTo: subjDoc.id)
            .where('date', isGreaterThanOrEqualTo: cutoff)
            .get();

        int present = 0, total = 0;
        final Map<String, bool> dayMap = {};
        for (final doc in attSnap.docs) {
          final data = doc.data();
          final records = Map<String, dynamic>.from(data['records'] ?? {});
          if (records.containsKey(widget.controller.studentId)) {
            total++;
            final isPresent = records[widget.controller.studentId] == true;
            if (isPresent) present++;
            dayMap[data['date'] as String] = isPresent;
          }
        }

        results.add(_SchoolSubjectAttendance(
          subjectId: subjDoc.id,
          subjectName: subjName,
          percent: total > 0 ? (present / total * 100) : null,
          dayMap: dayMap,
        ));
      }

      results.sort((a, b) => a.subjectName.compareTo(b.subjectName));

      if (!mounted) return;
      setState(() {
        _schoolSubjects = results;
        _selectedSchoolSubjectId = results.isNotEmpty ? results.first.subjectId : null;
        _isLoadingSchoolSubjects = false;
      });
    } catch (e) {
      debugPrint("Maktab fanlari davomatini yuklashda xato: $e");
      if (mounted) setState(() => _isLoadingSchoolSubjects = false);
    }
  }

  Color _chipColor(double p) {
    if (p >= 80) return const Color(0xFF10B981);
    if (p >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _percentChip({required String key, required String label, required double? percent, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    final c = percent != null ? _chipColor(percent) : const Color(0xFF94A3B8);
    final labelText = percent != null ? "$label: ${percent.toStringAsFixed(0)}%" : "$label: —";
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? c : c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? c : c.withOpacity(0.3), width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : c),
            const SizedBox(width: 5),
            Text(labelText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : c)),
          ],
        ),
      ),
    );
  }

  // YANGI (XATO TUZATILDI): Expanded endi BU YERDA EMAS — chaqiruvchi
  // tomonidan TASHQARIDAN qo'llanadi. Avval Expanded shu yerda, Obx
  // ICHIDA bo'lgani uchun Flutter uni Column'ning to'g'ridan-to'g'ri
  // farzandi deb tanimay, ULKAN RenderFlex overflow xatosiga olib
  // kelgan edi (kalendar cheksiz balandlikka cho'zilishga urinardi).
  Widget _buildCalendarInner(Map<String, bool> dayMap) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: TableCalendar(
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) => setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        }),
        onFormatChanged: (format) => setState(() => _calendarFormat = format),
        onPageChanged: (focusedDay) => _focusedDay = focusedDay,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
        ),
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle),
          selectedDecoration: BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
          defaultTextStyle: TextStyle(color: Color(0xFF1E293B)),
          weekendTextStyle: TextStyle(color: Color(0xFF64748B)),
        ),
        eventLoader: (day) {
          final dateKey = _dateKey(day);
          if (dayMap.containsKey(dateKey)) return [dayMap[dateKey]!];
          return [];
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            if (events.isNotEmpty) {
              bool isPresent = events.first as bool;
              return Container(
                margin: const EdgeInsets.all(4),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: isPresent ? const Color(0xFF22C55E) : const Color(0xFFEF4444), shape: BoxShape.circle),
                child: Text('${day.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              );
            }
            return null;
          },
        ),
      ),
    );
  }

  // YANGI: "Maktab" tabi — fanlar bo'yicha chip'lar + kalendar.
  Widget _buildSchoolTab() {
    if (_isLoadingSchoolSubjects) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }
    if (widget.controller.classId == null || widget.controller.classId!.isEmpty) {
      return const Center(child: Text("Bu o'quvchi maktabda o'qimaydi", style: TextStyle(color: Color(0xFF94A3B8))));
    }
    if (_schoolSubjects.isEmpty) {
      return const Center(child: Text("Bu sinfda fanlar topilmadi", style: TextStyle(color: Color(0xFF94A3B8))));
    }

    final selected = _schoolSubjects.firstWhere(
          (s) => s.subjectId == _selectedSchoolSubjectId,
      orElse: () => _schoolSubjects.first,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _schoolSubjects.map((s) {
              return _percentChip(
                key: s.subjectId,
                label: s.subjectName,
                percent: s.percent,
                icon: Icons.menu_book_rounded,
                isSelected: s.subjectId == _selectedSchoolSubjectId,
                onTap: () => setState(() => _selectedSchoolSubjectId = s.subjectId),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildCalendarInner(selected.dayMap)),
        ],
      ),
    );
  }

  // YANGI: "Markaz" tabi — avvalgi guruhlar mantig'i, o'zgarishsiz.
  Widget _buildCenterTab() {
    final controller = widget.controller;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            if (controller.isLoadingAttendanceSummary.value) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981))),
                    SizedBox(width: 10),
                    Text("Guruhlar davomati yuklanmoqda...", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ),
              );
            }

            final centerGroups = controller.centerAttendanceByGroup;
            if (centerGroups.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text("Bu o'quvchi hech qanday guruhda emas", style: TextStyle(color: Color(0xFF94A3B8)))),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: centerGroups.map((g) => _percentChip(
                  key: g['groupId'] as String,
                  label: g['name'] as String,
                  percent: g['percent'] as double,
                  icon: Icons.groups_rounded,
                  isSelected: _selectedCenterSource == g['groupId'],
                  onTap: () => setState(() => _selectedCenterSource = g['groupId'] as String),
                )).toList(),
              ),
            );
          }),
          const SizedBox(height: 12),
          // YANGI (XATO TUZATILDI): Expanded endi TASHQARIDA (Column'ning
          // to'g'ridan-to'g'ri farzandi), Obx esa ICHKARIDA — aks holda
          // Flutter Expanded'ni to'g'ri tanimay, ULKAN overflow
          // xatosiga olib kelardi.
          // YANGI (Obx olib tashlandi): bu yerda reaktivlik shart emas —
          // '_selectedCenterSource' o'zgarganda chip'ning onTap'idagi
          // setState() allaqachon butun ekranni qayta chizadi.
          Expanded(
            child: _buildCalendarInner(
              _selectedCenterSource != null
                  ? (controller.attendanceMapsBySource[_selectedCenterSource] ?? <String, bool>{})
                  : <String, bool>{},
            ),
          ),
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
        title: const Text("Davomat", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 17)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Maktab"),
            Tab(text: "Markaz"),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildSchoolTab(),
            _buildCenterTab(),
          ],
        ),
      ),
    );
  }
}


class _PaymentsScreen extends StatelessWidget {
  final StudentPaymentController paymentController;
  final String studentName;
  final String parentPhone;
  final bool hasSchoolClass;
  final bool fromCenterContext;
  final String? centerSubjectId;
  final DateTime? centerSubjectJoinedAt;
  final bool canViewPayments;
  final bool canEditPayments;
  final bool isLoadingPermissions;

  const _PaymentsScreen({
    required this.paymentController,
    required this.studentName,
    required this.parentPhone,
    this.hasSchoolClass = false,
    this.fromCenterContext = false,
    this.centerSubjectId,
    this.centerSubjectJoinedAt,
    this.canViewPayments = false,
    this.canEditPayments = false,
    this.isLoadingPermissions = true,
  });

  void _confirmDelete(BuildContext context, Map<String, dynamic> payment) {
    final currencyFormat = NumberFormat("#,###", "uz");
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Text("To'lovni o'chirish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "${currencyFormat.format(payment['amount'])} so'm miqdoridagi to'lovni o'chirmoqchimisiz? Bu amalni qaytarib bo'lmaydi.",
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFCBD5E1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () => Get.back(),
                      child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                      onPressed: () async {
                        Get.back();
                        await paymentController.deletePayment(payment['id']);
                      },
                      child: const Text("O'chirish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat("#,###", "uz");

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text("To'lovlar", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 17)),
      ),
      body: SafeArea(
        child: Builder(builder: (context) {
          if (isLoadingPermissions) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5));
          }

          if (!canViewPayments) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: const Color(0xFF94A3B8).withOpacity(0.08), shape: BoxShape.circle),
                      child: const Icon(Icons.lock_outline_rounded, size: 40, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 16),
                    const Text("To'lovlarni ko'rish uchun ruxsatingiz yo'q", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF334155)), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    const Text("Kerak bo'lsa, administratordan so'rang", style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: Obx(() {
                  if (paymentController.isLoading.value) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5));
                  }

                  final payments = paymentController.payments;

                  return RefreshIndicator(
                    color: const Color(0xFF10B981),
                    onRefresh: paymentController.refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      children: [
                        if (hasSchoolClass && fromCenterContext) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBFDBFE))),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.verified_rounded, color: Color(0xFF3B82F6), size: 18),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    "Bu o'quvchi maktabda o'qiydi — O'quv Markaz to'lovlaridan OZOD",
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF), height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (fromCenterContext && !hasSchoolClass && centerSubjectId != null) ...[
                          Obx(() {
                            final paid = paymentController.hasSubjectPaymentThisMonth(centerSubjectId!);
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: paid ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: paid ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: (paid ? const Color(0xFF10B981) : const Color(0xFFD97706)).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                    child: Icon(paid ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: paid ? const Color(0xFF10B981) : const Color(0xFFD97706), size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          paid ? "Bu fan uchun shu oy to'langan (barcha guruhlarga amal qiladi)" : "Bu fan uchun shu oy hali to'lanmagan",
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: paid ? const Color(0xFF065F46) : const Color(0xFF92400E), height: 1.3),
                                        ),
                                        if (centerSubjectJoinedAt != null) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            "Bu fanga ${DateFormat('dd.MM.yyyy').format(centerSubjectJoinedAt!)} dan a'zo",
                                            style: TextStyle(fontSize: 11, color: (paid ? const Color(0xFF065F46) : const Color(0xFF92400E)).withOpacity(0.75)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Shu oy to'langan", style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                              const SizedBox(height: 6),
                              Text("${currencyFormat.format(paymentController.totalPaidThisMonth)} so'm", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              if (paymentController.hasSchoolPaymentThisMonth) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: const [
                                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text("Bu oy uchun maktab to'lovi qilingan", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        const Text("To'lovlar tarixi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                        const SizedBox(height: 10),

                        if (payments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                children: const [
                                  Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
                                  SizedBox(height: 12),
                                  Text("Hali to'lovlar yo'q", style: TextStyle(color: Color(0xFF94A3B8))),
                                ],
                              ),
                            ),
                          )
                        else
                          ...payments.map((p) {
                            final method = p['method'] as String;
                            final methodLabel = method == 'card' ? "Karta" : (method == 'bank_transfer' ? "O'tkazma" : "Naqt");
                            final date = DateTime.fromMillisecondsSinceEpoch(p['dateMs'] ?? 0);
                            final bool isLocked = p['isLocked'] == true;

                            final forMonthKey = p['forMonth'] as String? ?? '';
                            String? forMonthLabel;
                            if (forMonthKey.contains('-')) {
                              final parts = forMonthKey.split('-');
                              final y = int.tryParse(parts[0]);
                              final m = int.tryParse(parts[1]);
                              if (y != null && m != null) forMonthLabel = monthLabelOf(DateTime(y, m), withYear: true);
                            }

                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => showPaymentSuccessDialog(
                                studentName: studentName,
                                amount: p['amount'] as double,
                                date: date,
                                method: method,
                                parentPhone: parentPhone,
                                forMonthLabel: forMonthLabel,
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEEF2F6))),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: (isLocked ? const Color(0xFF94A3B8) : const Color(0xFF10B981)).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(isLocked ? Icons.lock_rounded : Icons.check_circle_outline_rounded, color: isLocked ? const Color(0xFF94A3B8) : const Color(0xFF10B981), size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("${currencyFormat.format(p['amount'])} so'm", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B))),
                                          const SizedBox(height: 2),
                                          Text(
                                            forMonthLabel != null
                                                ? "$methodLabel · ${DateFormat('dd.MM.yyyy').format(date)} · $forMonthLabel uchun"
                                                : "$methodLabel · ${DateFormat('dd.MM.yyyy').format(date)}",
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isLocked || !canEditPayments)
                                      const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFFCBD5E1)))
                                    else
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8), size: 20),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            showAddPaymentDialog(context, paymentController, studentName, parentPhone: parentPhone, existingPayment: p);
                                          } else if (value == 'delete') {
                                            _confirmDelete(context, p);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: Color(0xFF3B82F6)), SizedBox(width: 10), Text("Tahrirlash")])),
                                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)), SizedBox(width: 10), Text("O'chirish", style: TextStyle(color: Color(0xFFDC2626)))])),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                }),
              ),

              if (hasSchoolClass && fromCenterContext)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border(top: BorderSide(color: Colors.grey.shade200))),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text("Kurs to'lovidan ozod", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13.5))),
                  ),
                )
              else if (!canEditPayments)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border(top: BorderSide(color: Colors.grey.shade200))),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                        SizedBox(width: 8),
                        Text("To'lov qo'shish huquqingiz yo'q", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13.5)),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border(top: BorderSide(color: Colors.grey.shade200))),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      onPressed: () => showAddPaymentDialog(
                        context,
                        paymentController,
                        studentName,
                        parentPhone: parentPhone,
                        defaultSource: fromCenterContext ? 'tutoring' : 'school',
                        defaultForSubjectId: fromCenterContext ? centerSubjectId : null,
                      ),
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: const Text("To'lov qo'shish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5)),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _ExamResultsScreen extends StatelessWidget {
  final String studentName;
  final bool isLoading;
  final List<_ExamResultEntry> results;

  const _ExamResultsScreen({required this.studentName, required this.isLoading, required this.results});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text("Imtihon natijalari", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 17)),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
            : results.isEmpty
            ? const Center(child: Text("Hali imtihon natijalari yo'q", style: TextStyle(color: Color(0xFF94A3B8))))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final e = results[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEEF2F6))),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.quiz_rounded, size: 18, color: Color(0xFF8B5CF6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.examName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B))),
                        const SizedBox(height: 2),
                        Text(
                          "${e.sourceLabel}${e.date != null ? ' · ${DateFormat('dd.MM.yyyy').format(e.date!)}' : ''}",
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(e.displayScore, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6D28D9))),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FullscreenPhotoView extends StatelessWidget {
  final String photoUrl;
  final String heroTag;

  const _FullscreenPhotoView({required this.photoUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: heroTag,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
                    errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28), onPressed: () => Navigator.of(context).pop()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}