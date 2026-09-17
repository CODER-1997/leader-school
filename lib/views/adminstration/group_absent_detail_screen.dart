import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/admin_controller/admin_settings_controller.dart'; // MUHIM: sizning haqiqiy yo'lingizga moslang
 import '../../controllers/admin_controller/group_absent_detail_controller.dart';
import '../../services/get_helper.dart';
import '../../services/sms_service.dart'; // MUHIM: shu ham

/// BOSQICH-2 EKRANI — bitta sinf/guruhning barcha o'quvchilari, har
/// birida OXIRGI 30 KUNLIK davomat foizi va BUGUNGI holati. Bosilsa —
/// SMS/qo'ng'iroq oynasi.
class GroupAbsentDetailScreen extends StatefulWidget {
  final String id;
  final String name;
  final bool isSchool;

  const GroupAbsentDetailScreen({super.key, required this.id, required this.name, required this.isSchool});

  @override
  State<GroupAbsentDetailScreen> createState() => _GroupAbsentDetailScreenState();
}

class _GroupAbsentDetailScreenState extends State<GroupAbsentDetailScreen> {
  late GroupAbsentDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = putOnce(
          () => GroupAbsentDetailController(id: widget.id, isSchool: widget.isSchool),
      tag: 'absent_detail_${widget.id}',
    );
  }

  @override
  void dispose() {
    Get.delete<GroupAbsentDetailController>(tag: 'absent_detail_${widget.id}');
    super.dispose();
  }

  String _capitalize(String text) {
    if (text.isEmpty) return '';
    return text.trim().split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _fullName(Map<String, dynamic> s) {
    final last = _capitalize(s['lastName'] ?? '');
    final first = _capitalize(s['firstName'] ?? '');
    return (last.isNotEmpty && first.isNotEmpty) ? "$last $first" : _capitalize(s['name'] ?? 'Nomsiz');
  }

  Color _percentColor(double percent) {
    if (percent >= 80) return const Color(0xFF10B981);
    if (percent >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Future<void> _callParent(String phone) async {
    if (phone.trim().isEmpty) {
      Get.snackbar("Diqqat", "Ota-ona telefon raqami kiritilmagan", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    final uri = Uri.parse('tel:${phone.trim()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Get.snackbar("Xatolik", "Qo'ng'iroqni ochib bo'lmadi", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _smsParent(Map<String, dynamic> student) async {
    final phone = (student['parentPhone'] ?? '').toString().trim();
    if (phone.isEmpty) {
      Get.snackbar("Diqqat", "Ota-ona telefon raqami kiritilmagan", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('sms_templates').get();
      final template = (doc.data()?['attendance'] ?? AdminSettingsController.defaultAttendanceTemplate).toString();
      final today = DateFormat('dd.MM.yyyy').format(DateTime.now());

      final message = template
          .replaceAll('{ism}', _fullName(student))
          .replaceAll('{sinf}', widget.name)
          .replaceAll('{sana}', today);

      await SMSService().sendSMS(phone, message);
      Get.snackbar("Yuborildi", "SMS ota-onaga yuborildi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xatolik", "SMS yuborishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _showContactSheet(Map<String, dynamic> student) {
    final phone = (student['parentPhone'] ?? '').toString();
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
            Text(_fullName(student), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(
              phone.isNotEmpty ? "Ota-ona: $phone" : "Ota-ona raqami kiritilmagan",
              style: TextStyle(fontSize: 13, color: phone.isNotEmpty ? const Color(0xFF94A3B8) : const Color(0xFFDC2626)),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.sms_rounded, color: Color(0xFF3B82F6)),
              ),
              title: const Text("SMS orqali ogohlantirish"),
              onTap: () {
                Get.back();
                _smsParent(student);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.call_rounded, color: Color(0xFF10B981)),
              ),
              title: const Text("Qo'ng'iroq qilish"),
              onTap: () {
                Get.back();
                _callParent(phone);
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
        }

        if (_controller.errorMessage.value != null) {
          return Padding(
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
                  SelectableText(_controller.errorMessage.value!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontFamily: 'monospace')),
                ],
              ),
            ),
          );
        }

        final students = _controller.students;
        if (students.isEmpty) {
          return const Center(child: Text("O'quvchilar yo'q", style: TextStyle(color: Color(0xFF94A3B8))));
        }

        return RefreshIndicator(
          color: const Color(0xFF10B981),
          onRefresh: _controller.refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final s = students[index];
              final bool absentToday = s['absentToday'] == true;
              final double percent = s['attendancePercent'] as double;
              final int sample = s['attendanceSampleSize'] as int;
              final phone = (s['parentPhone'] ?? '').toString();

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showContactSheet(s),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: absentToday ? const Color(0xFFFECACA) : const Color(0xFFEEF2F6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (absentToday ? const Color(0xFFDC2626) : const Color(0xFF10B981)).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          absentToday ? Icons.person_off_rounded : Icons.person_rounded,
                          color: absentToday ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_fullName(s), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (absentToday) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                                    child: const Text("Bugun yo'q", style: TextStyle(fontSize: 10.5, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  sample > 0 ? "${percent.toStringAsFixed(0)}% davomat (${sample} kun)" : "Ma'lumot yo'q",
                                  style: TextStyle(fontSize: 11.5, color: sample > 0 ? _percentColor(percent) : const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}