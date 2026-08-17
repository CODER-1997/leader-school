import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leader_school/views/adminstration/teacher/teacher_profile_view.dart';

import '../../controllers/admin_controller/admin_teacher_controller.dart';
import '../../services/get_helper.dart';
import '../../widgets/teacher_form_sheet.dart';


class AdminTeachersScreen extends StatelessWidget {
  const AdminTeachersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = putOnce(() => AdminTeacherController(), tag: 'admin_teachers');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        onPressed: () => Get.to(() => TeacherFormScreen(controller: controller)),
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text("Qo'shish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5));
        }

        final teachers = controller.teachers;

        return RefreshIndicator(
          color: const Color(0xFF10B981),
          onRefresh: controller.refresh,
          child: teachers.isEmpty
              ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), shape: BoxShape.circle),
                        child: const Icon(Icons.people_alt_outlined, size: 40, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 16),
                      const Text("Hozircha hech kim yo'q", style: TextStyle(color: Color(0xFF334155), fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text(
                        "Pastdagi tugma orqali birinchi\no'qituvchi yoki admin qo'shing",
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
              : ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final t = teachers[index];

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Get.to(() => TeacherProfileView(teacherId: t.id, controller: controller)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEEF2F6)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: !t.isActive
                              ? const Color(0xFFF1F5F9)
                              : (t.isAdmin ? const Color(0xFF8B5CF6).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.12)),
                          child: Icon(
                            t.isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                            color: !t.isActive ? const Color(0xFF94A3B8) : (t.isAdmin ? const Color(0xFF8B5CF6) : const Color(0xFF10B981)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.isAdmin ? "Admin" : "O'qituvchi",
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TeacherStatusBadge(teacher: t),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                      ],
                    ),
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

/// Bitta, aniq status belgisi — ikkita alohida badge (Faol/Nofaol +
/// Kirmagan) bir-biriga tiqilib, karta torayib qolishining oldini oladi.
/// Ustuvorlik: Nofaol > Kirmagan > Faol.
class _TeacherStatusBadge extends StatelessWidget {
  final TeacherSummary teacher;
  const _TeacherStatusBadge({required this.teacher});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;

    if (!teacher.isActive) {
      label = "Nofaol";
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF94A3B8);
    } else if (teacher.lastLoginAt == null) {
      label = "Kirmagan";
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
    } else {
      label = "Faol";
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}