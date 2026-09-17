import 'package:flutter/material.dart';
import 'package:get/get.dart';

 import '../../controllers/admin_controller/admin_absent_student_controller.dart';
import '../../services/get_helper.dart';
import 'group_absent_detail_screen.dart';

/// BOSQICH-1 EKRANI — sinflar/guruhlar ro'yxati, yonida "N kelmagan"
/// belgisi. Bosilsa — o'sha sinf/guruhning o'quvchilari (BOSQICH-2)
/// ochiladi.
///
/// MUHIM: bu widget o'z Scaffold/AppBar'ini OLIB YURMAYDI — AdminMainView
/// allaqachon tashqi Scaffold+AppBar beradi.
class AdminAbsentStudentsScreen extends StatelessWidget {
  const AdminAbsentStudentsScreen({super.key});

  Widget _buildGroupList(BuildContext context, AdminAbsentGroupsController controller, List<Map<String, dynamic>> groups, bool isSchool) {
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(isSchool ? Icons.class_outlined : Icons.groups_outlined, size: 40, color: const Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            Text(isSchool ? "Hozircha sinflar yo'q" : "Hozircha guruhlar yo'q", style: const TextStyle(color: Color(0xFF334155), fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF10B981),
      onRefresh: controller.refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final g = groups[index];
          final int absentCount = g['absentCount'] as int;
          final bool hasAbsent = absentCount > 0;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Get.to(() => GroupAbsentDetailScreen(id: g['id'], name: g['name'], isSchool: isSchool)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: hasAbsent ? const Color(0xFFFECACA) : const Color(0xFFEEF2F6)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: (hasAbsent ? const Color(0xFFDC2626) : const Color(0xFF10B981)).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(isSchool ? Icons.class_rounded : Icons.groups_rounded, color: hasAbsent ? const Color(0xFFDC2626) : const Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(g['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Color(0xFF1E293B))),
                    ),
                    if (hasAbsent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(10)),
                        child: Text("$absentCount kelmagan", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                        child: const Text("Hammasi keldi", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = putOnce(() => AdminAbsentGroupsController(), tag: 'admin_absent_groups');

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Color(0xFF10B981),
              unselectedLabelColor: Color(0xFF64748B),
              indicatorColor: Color(0xFF10B981),
              indicatorWeight: 3,
              tabs: [
                Tab(text: "Maktab"),
                Tab(text: "O'quv Markaz"),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
              }

              if (controller.errorMessage.value != null) {
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
                        SelectableText(controller.errorMessage.value!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                );
              }

              return TabBarView(
                children: [
                  _buildGroupList(context, controller, controller.schoolClasses, true),
                  _buildGroupList(context, controller, controller.centerGroups, false),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}