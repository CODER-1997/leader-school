import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/admin_controller/admin_settings_controller.dart'; // MUHIM: haqiqiy yo'lingizga moslang
 import '../../controllers/school_absentees_controller.dart';
import '../../services/sms_service.dart';

/// Bitta SINF-FAN birikmasida BUGUN kelmagan o'quvchilar ro'yxati.
/// GroupAbsenteesDetailView (O'quv Markaz) bilan BIR XIL ko'rinish va
/// funksionallik — farqi: SMS "Maktab" shablonidan (`attendance` /
/// `{sinf}` joy-belgisi) foydalanadi, `CenterSmsService` EMAS.
///
/// ODDIY BOSISH — Qo'ng'iroq/SMS tanlash dialogi (bitta o'quvchi uchun).
/// UZOQ BOSISH — ro'yxatdagi BARCHA o'quvchilar tanlanadi, keyin pastda
/// "SMS yuborish (N)" tugmasi orqali ommaviy yuboriladi.
class ClassSubjectAbsenteesDetailView extends StatefulWidget {
  final String classId;
  final String subjectId;
  final String displayTitle; // "Sinf - Fan", masalan "9-A - Matematika"
  final List<String> studentIds;
  final String attendanceDocId;

  const ClassSubjectAbsenteesDetailView({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.displayTitle,
    required this.studentIds,
    required this.attendanceDocId,
  });

  @override
  State<ClassSubjectAbsenteesDetailView> createState() => _ClassSubjectAbsenteesDetailViewState();
}

class _ClassSubjectAbsenteesDetailViewState extends State<ClassSubjectAbsenteesDetailView> {
  bool _loading = true;
  List<Map<String, dynamic>> _students = []; // {id, name, phone, parentPhone}

  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  bool _isSendingBulk = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final db = FirebaseFirestore.instance;
    final List<Map<String, dynamic>> result = [];

    for (var i = 0; i < widget.studentIds.length; i += 10) {
      final end = (i + 10 > widget.studentIds.length) ? widget.studentIds.length : i + 10;
      final chunk = widget.studentIds.sublist(i, end);

      final snap = await db.collection('students').where(FieldPath.documentId, whereIn: chunk).get();

      for (var doc in snap.docs) {
        final data = doc.data();

        // Arxivlangan (o'chirilgan) o'quvchi bu ro'yxatda ko'rinmasligi kerak.
        if (data['isArchived'] == true) continue;

        final name = (data['name'] ?? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}').toString().trim();
        result.add({
          'id': doc.id,
          'name': name.isEmpty ? 'Nomsiz' : name,
          'firstName': (data['firstName'] ?? '').toString(),
          'lastName': (data['lastName'] ?? '').toString(),
          'phone': (data['phone'] ?? '').toString(),
          'parentPhone': (data['parentPhone'] ?? '').toString(),
        });
      }
    }

    if (mounted) {
      setState(() {
        _students = result;
        _loading = false;
      });
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  bool _isValidPhone(String? phone) {
    if (phone == null) return false;
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == "Kiritilmagan") return false; // YANGI: joy-belgisi haqiqiy raqam emas
    return true;
  }

  String _resolvePhone(Map<String, dynamic> student) {
    final parent = student['parentPhone'] as String?;
    if (_isValidPhone(parent)) return parent!;
    final own = student['phone'] as String?;
    if (_isValidPhone(own)) return own!;
    return '';
  }

  Future<void> _callStudent(String phone) async {
    if (phone.isEmpty) {
      Get.snackbar("Xato", "Telefon raqami topilmadi", backgroundColor: const Color(0xFFFEF2F2), colorText: const Color(0xFFDC2626));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// MAKTAB "kelmadi" shabloni orqali SMS yuboradi — Firestore:
  /// settings/sms_templates -> 'attendance' maydoni, '{sinf}' joy-
  /// belgisi shu sinf-fan sarlavhasi (masalan "9-A - Matematika")
  /// bilan almashtiriladi.
  Future<Map<String, int>> _sendSchoolAbsenceSms(List<Map<String, dynamic>> students) async {
    String template;
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('sms_templates').get();
      template = doc.data()?['attendance'] ?? AdminSettingsController.defaultAttendanceTemplate;
    } catch (e) {
      template = AdminSettingsController.defaultAttendanceTemplate;
    }

    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
    final smsService = SMSService();

    int successCount = 0;
    int failCount = 0;

    for (final student in students) {
      final fullName = student['name'] as String;
      final message = template
          .replaceAll('{ism}', fullName)
          .replaceAll('{sinf}', widget.displayTitle)
          .replaceAll('{sana}', today);

      final recipient = _resolvePhone(student);
      if (recipient.isEmpty) {
        failCount++;
        continue;
      }

      try {
        await smsService.sendSMS(recipient, message);
        successCount++;
      } catch (e) {
        failCount++;
        debugPrint("Maktab kelmagan SMS xatosi ($fullName): $e");
      }
    }

    return {'success': successCount, 'fail': failCount};
  }

  Future<void> _sendSingleAbsenceSms(Map<String, dynamic> student) async {
    await _sendSchoolAbsenceSms([student]);
    await _markGroupNotified();
  }

  /// SMS yuborilgach — bu SINF-FAN birikmasi uchun "ogohlantirilgan"
  /// deb belgilaydi (individual emas, GURUH/BIRIKMA darajasida) va
  /// tashqi ro'yxat (agar xotirada bo'lsa) darhol yangilanadi.
  Future<void> _markGroupNotified() async {
    if (widget.attendanceDocId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(widget.attendanceDocId)
          .update({'absenteesSmsNotifiedAt': FieldValue.serverTimestamp()});

      if (Get.isRegistered<SchoolAbsenteesController>(tag: 'school_absentees_all')) {
        Get.find<SchoolAbsenteesController>(tag: 'school_absentees_all').loadData();
      }
    } catch (e) {
      debugPrint("Sinf-fanni ogohlantirilgan deb belgilashda xato: $e");
    }
  }

  void _onLongPressStudent() {
    if (_selectionMode) return;
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(_students.map((s) => s['id'] as String));
    });
  }

  void _toggleSelection(String studentId) {
    setState(() {
      if (_selectedIds.contains(studentId)) {
        _selectedIds.remove(studentId);
      } else {
        _selectedIds.add(studentId);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _confirmAndSendBulkSms() async {
    final count = _selectedIds.length;

    final confirmed = await Get.dialog<bool>(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, 12))],
          ),
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
                    TextSpan(text: "$count ta o'quvchi", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    const TextSpan(text: "ning ota-onasiga \"kelmadi\" haqida SMS yuboriladi. Davom etasizmi?"),
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

    if (confirmed != true) return;

    setState(() => _isSendingBulk = true);
    try {
      final selectedStudents = _students.where((s) => _selectedIds.contains(s['id'])).toList();
      final result = await _sendSchoolAbsenceSms(selectedStudents);
      await _markGroupNotified();

      Get.snackbar(
        result['fail'] == 0 ? "Yuborildi" : "Qisman yuborildi",
        "${result['success']} ta yuborildi${result['fail']! > 0 ? ', ${result['fail']} ta xato' : ''}",
        backgroundColor: result['fail'] == 0 ? const Color(0xFF10B981) : Colors.orange,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingBulk = false;
          _selectionMode = false;
          _selectedIds.clear();
        });
      }
    }
  }

  void _showContactDialog(Map<String, dynamic> student) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
                child: Center(
                  child: Text(_initials(student['name']), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 18)),
                ),
              ),
              const SizedBox(height: 14),
              Text(student['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Text(widget.displayTitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
              const SizedBox(height: 6),
              Builder(builder: (context) {
                final phone = _resolvePhone(student);
                final isParent = (student['parentPhone'] as String? ?? '').isNotEmpty;
                if (phone.isEmpty) return const SizedBox.shrink();
                return Text("${isParent ? "Ota-ona" : "O'quvchi"}: $phone", style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600));
              }),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _ContactActionButton(
                      icon: Icons.call_rounded,
                      label: "Qo'ng'iroq",
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        Get.back();
                        _callStudent(_resolvePhone(student));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ContactActionButton(
                      icon: Icons.sms_rounded,
                      label: "SMS",
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Get.back();
                        _sendSingleAbsenceSms(student);
                      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _selectionMode
            ? IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)), onPressed: _cancelSelection)
            : null,
        title: Text(
          _selectionMode ? "${_selectedIds.length} ta tanlandi" : widget.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      bottomNavigationBar: _selectionMode
          ? Container(
        padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -6))]),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: const StadiumBorder(), elevation: 0),
            onPressed: (_isSendingBulk || _selectedIds.isEmpty) ? null : _confirmAndSendBulkSms,
            icon: _isSendingBulk
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sms_rounded, color: Colors.white),
            label: Text(
              _isSendingBulk ? "Yuborilmoqda..." : "SMS yuborish (${_selectedIds.length})",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5),
            ),
          ),
        ),
      )
          : null,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
            : _students.isEmpty
            ? const Center(child: Text("Kelmagan o'quvchi yo'q", style: TextStyle(color: Color(0xFF94A3B8))))
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: _students.length,
          itemBuilder: (context, index) {
            final st = _students[index];
            final studentId = st['id'] as String;
            final bool isSelected = _selectedIds.contains(studentId);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onLongPress: _onLongPressStudent,
                onTap: _selectionMode ? () => _toggleSelection(studentId) : () => _showContactDialog(st),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF10B981).withOpacity(0.07) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFFEEF2F6)),
                  ),
                  child: Row(
                    children: [
                      if (_selectionMode)
                        Container(
                          height: 44, width: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? const Color(0xFF10B981) : Colors.white,
                            border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1), width: 2),
                          ),
                          child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                        )
                      else
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.08), shape: BoxShape.circle),
                          child: Center(
                            child: Text(_initials(st['name']), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                          ),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(st['name'], style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 14.5)),
                            if ((st['phone'] as String).isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(st['phone'], style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                            ],
                          ],
                        ),
                      ),
                      if (!_selectionMode) const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}