import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
// MUHIM: agar `url_launcher` paketi loyihada hali qo'shilmagan bo'lsa:
//   flutter pub add url_launcher

import '../../controllers/center/attendance_controller.dart';
import '../../controllers/center/center_absentees_controller.dart'; // YANGI

/// Bitta guruhda BUGUN kelmagan o'quvchilar ro'yxati.
///
/// ODDIY BOSISH — avvalgidek: Qo'ng'iroq / SMS tanlash dialogi chiqadi
/// (FAQAT o'sha bitta o'quvchi uchun).
///
/// YANGI: UZOQ BOSISH (istalgan o'quvchida) — RO'YXATDAGI BARCHA
/// o'quvchilar darhol TANLANADI (chunki bu ro'yxatning o'zi — "bugun
/// kelmaganlar", demak odatda hammasiga SMS ketishi kerak bo'ladi).
/// Shundan keyin pastda "SMS yuborish (N)" tugmasi chiqadi — kerak
/// bo'lsa ba'zilarini bosib o'chirib qo'yish mumkin.
///
/// YANGI (XATO TUZATILDI): agar o'quvchi keyinchalik ARXIVLANGAN
/// (o'chirilgan) bo'lsa — bu ro'yxatda UMUMAN ko'rinmaydi, garchi
/// bugungi attendance yozuvida hali "kelmagan" deb qolgan bo'lsa ham.
class GroupAbsenteesDetailView extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<String> studentIds;
  final String attendanceDocId; // YANGI: SMS holatini shu hujjatga yozish uchun

  const GroupAbsenteesDetailView({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.studentIds,
    required this.attendanceDocId,
  });

  @override
  State<GroupAbsenteesDetailView> createState() =>
      _GroupAbsenteesDetailViewState();
}

class _GroupAbsenteesDetailViewState extends State<GroupAbsenteesDetailView> {
  bool _loading = true;
  List<Map<String, dynamic>> _students = []; // {id, name, phone}

  // YANGI: tanlash rejimi holati.
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
      final end =
      (i + 10 > widget.studentIds.length) ? widget.studentIds.length : i + 10;
      final chunk = widget.studentIds.sublist(i, end);

      // HAQIQIY SXEMA (GroupStudentsController'dan tasdiqlangan):
      // 'name' = "$firstName $lastName", 'phone' = o'quvchining o'zi,
      // 'parentPhone' = ota-ona raqami. firstName/lastName ham
      // olinadi — CenterSmsService._fullName() shularni kutadi.
      final snap = await db
          .collection('students')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (var doc in snap.docs) {
        final data = doc.data();

        // YANGI: arxivlangan (o'chirilgan) o'quvchi bu ro'yxatda
        // UMUMAN ko'rinmasligi kerak.
        if (data['isArchived'] == true) continue;

        final name = (data['name'] ??
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
            .toString()
            .trim();
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

  /// Xabar berish uchun qaysi raqam ishlatilishini aniqlaydi — kelmagan
  /// haqida odatda OTA-ONAGA xabar berish ma'noliroq, shuning uchun
  /// avval `parentPhone`, u bo'sh bo'lsa `phone` (o'quvchining o'zi)
  /// ishlatiladi.
  String _resolvePhone(Map<String, dynamic> student) {
    final parent = (student['parentPhone'] as String?) ?? '';
    if (parent.isNotEmpty) return parent;
    return (student['phone'] as String?) ?? '';
  }

  Future<void> _callStudent(String phone) async {
    if (phone.isEmpty) {
      Get.snackbar("Xato", "Telefon raqami topilmadi",
          backgroundColor: const Color(0xFFFEF2F2),
          colorText: const Color(0xFFDC2626));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendAbsenceSms(Map<String, dynamic> student) async {
    // Sizning mavjud CenterSmsService orqali yuboriladi — shu bilan
    // "kelmadi" shablonidan (Firestore: settings/sms_templates ->
    // 'centerAttendance' maydoni) foydalaniladi, xuddi guruh ichidagi
    // davomat ekranida ishlaganidek.
    final studentId = student['id'] as String;
    final smsService = CenterSmsService();
    smsService.selectedIds.add(studentId);

    await smsService.sendAttendanceSms(
      allStudents: [student],
      attendanceMap: {studentId: false}, // false = kelmagan
      groupName: widget.groupName,
    );
    await _markGroupNotified(); // YANGI
  }

  // YANGI: SMS yuborilgach — bu GURUH uchun (kim ekanidan qat'i nazar)
  // "ogohlantirilgan" deb belgilaydi. Bu — individual o'quvchi emas,
  // GURUH DARAJASIDAGI holat (tashqi ro'yxatda, "N kishi" yonida
  // ko'rinadi).
  Future<void> _markGroupNotified() async {
    if (widget.attendanceDocId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(widget.attendanceDocId)
          .update({'absenteesSmsNotifiedAt': FieldValue.serverTimestamp()});

      // YANGI: agar tashqi (guruhlar ro'yxati) ekrani hali xotirada
      // bo'lsa — uni ham darhol yangilaymiz, shunda ortga qaytilganda
      // "Ogohlantirilgan" belgisi pull-to-refresh kutmasdan ko'rinadi.
      if (Get.isRegistered<CenterAbsenteesController>(tag: 'center_absentees_all')) {
        Get.find<CenterAbsenteesController>(tag: 'center_absentees_all').loadData();
      }
    } catch (e) {
      debugPrint("Guruhni ogohlantirilgan deb belgilashda xato: $e");
    }
  }

  // =======================================================================
  // YANGI: uzoq bosilganda — RO'YXATDAGI BARCHA o'quvchilarni tanlaydi.
  // =======================================================================
  void _onLongPressStudent() {
    if (_selectionMode) return; // allaqachon tanlash rejimida — hech narsa qilmaydi
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
      final smsService = CenterSmsService();
      smsService.selectedIds.addAll(_selectedIds);

      final attendanceMap = {for (final id in _selectedIds) id: false};

      await smsService.sendAttendanceSms(
        allStudents: selectedStudents,
        attendanceMap: attendanceMap,
        groupName: widget.groupName,
      );
      await _markGroupNotified(); // YANGI
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
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials(student['name']),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                        fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                student['name'],
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(widget.groupName,
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF94A3B8))),
              const SizedBox(height: 6),
              Builder(builder: (context) {
                final phone = _resolvePhone(student);
                final isParent =
                    (student['parentPhone'] as String? ?? '').isNotEmpty;
                if (phone.isEmpty) return const SizedBox.shrink();
                return Text(
                  "${isParent ? "Ota-ona" : "O'quvchi"}: $phone",
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600),
                );
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
                        _sendAbsenceSms(student);
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
        // YANGI: tanlash rejimida "X" (bekor qilish), aks holda oddiy orqaga.
        leading: _selectionMode
            ? IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)), onPressed: _cancelSelection)
            : null,
        title: Text(
          _selectionMode ? "${_selectedIds.length} ta tanlandi" : widget.groupName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      // YANGI: tanlash rejimida pastda "SMS yuborish (N)" tugmasi.
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
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)))
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
              // YANGI: uzoq bosish — hammasini tanlaydi. Oddiy bosish —
              // tanlash rejimida bo'lsa TOGGLE, aks holda AVVALGIDEK
              // aloqa dialogini ochadi.
              onLongPress: _onLongPressStudent,
              onTap: _selectionMode ? () => _toggleSelection(studentId) : () => _showContactDialog(st),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF10B981).withOpacity(0.07) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFFEEF2F6)),
                ),
                child: Row(
                  children: [
                    // YANGI: tanlash rejimida — belgi doirasi; aks
                    // holda — avvalgi bosh harflar doirasi.
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
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _initials(st['name']),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626)),
                          ),
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(st['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                  fontSize: 14.5)),
                          if ((st['phone'] as String).isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(st['phone'],
                                style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12.5)),
                          ],
                        ],
                      ),
                    ),
                    if (!_selectionMode)
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFFCBD5E1)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

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
              Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}