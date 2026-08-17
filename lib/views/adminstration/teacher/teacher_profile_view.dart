import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/admin_controller/admin_teacher_controller.dart';
import '../../../widgets/teacher_form_sheet.dart';


class TeacherProfileView extends StatelessWidget {
  final String teacherId;
  final AdminTeacherController controller;

  const TeacherProfileView({super.key, required this.teacherId, required this.controller});

  /// Vaqtni "5 daqiqa oldin", "Kecha, 14:32" kabi inson o'qiy oladigan
  /// shaklga o'giradi.
  String _humanTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return "Hozirgina";
    if (diff.inMinutes < 60) return "${diff.inMinutes} daqiqa oldin";
    if (diff.inHours < 24 && dt.day == now.day) return "${diff.inHours} soat oldin";

    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return "Kecha, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
  }

  void _confirmDelete(BuildContext context, TeacherSummary t) {
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
                const Expanded(child: Text("Ma'lumotni o'chirish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
              ],
            ),
            const SizedBox(height: 12),
            Text("\"${t.fullName}\" ma'lumotini butunlay o'chirmoqchimisiz?", style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4)),
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
                        Get.back(); // bottom sheet
                        final ok = await controller.deleteTeacher(t.id);
                        if (ok) Get.back(); // profil ekranidan chiqish
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
    return Obx(() {
      final t = controller.getTeacher(teacherId);

      if (t == null) {
        // O'chirilgan yoki topilmadi
        return Scaffold(
          appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Color(0xFF0F172A))),
          body: const Center(child: Text("Ma'lumot topilmadi", style: TextStyle(color: Color(0xFF94A3B8)))),
        );
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          title: const Text("Profil", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B)),
              onPressed: () => Get.to(() => TeacherFormScreen(controller: controller, existing: t)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
              onPressed: () => _confirmDelete(context, t),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: t.isAdmin ? const Color(0xFF8B5CF6).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.12),
                    child: Icon(
                      t.isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                      size: 38,
                      color: t.isAdmin ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(t.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(t.phone, style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: t.isAdmin ? const Color(0xFF8B5CF6).withOpacity(0.1) : const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      t.isAdmin ? "Admin" : "O'qituvchi",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: t.isAdmin ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _SectionCard(
              title: "Holat",
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.isActive ? "Faol" : "Nofaol", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8))),
                  Switch.adaptive(
                    value: t.isActive,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (v) => controller.setActive(t.id, v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _SectionCard(
              title: "Faollik",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Holati", style: TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: t.lastLoginAt != null ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t.lastLoginAt != null ? "Tizimga kirgan" : "Hali kirmagan",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: t.lastLoginAt != null ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("So'nggi kirish", style: TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
                      Text(
                        t.lastLoginAt != null ? _humanTime(t.lastLoginAt!) : "—",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Jami kirishlar", style: TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
                      Text(
                        "${t.loginCount}",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _SectionCard(
              title: "Ruxsatlar",
              child: Column(
                children: [
                  _PermissionRow(
                    label: "To'lovlarni ko'rish",
                    value: t.canViewPayments,
                    onChanged: (v) => controller.setPermission(t.id, 'viewPayments', v),
                  ),
                  _PermissionRow(
                    label: "To'lovlarni tahrirlash",
                    value: t.canEditPayments,
                    onChanged: (v) => controller.setPermission(t.id, 'editPayments', v),
                  ),
                  _PermissionRow(
                    label: "SMS yuborish",
                    value: t.canSendSms,
                    onChanged: (v) => controller.setPermission(t.id, 'sendSms', v),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF2F6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF334155))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
          Switch.adaptive(value: value, activeColor: const Color(0xFF10B981), onChanged: onChanged),
        ],
      ),
    );
  }
}