import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/center/center_absentees_controller.dart';
import '../../services/get_helper.dart'; // MUHIM: haqiqiy yo'lingizga moslang
import 'group_absentees_detail_view.dart';

/// "Kelmaganlar" bo'limi (markaz bo'ylab) — bugun davomat olingan va
/// kamida bitta kelmagan o'quvchisi bo'lgan guruhlarni card
/// ko'rinishida chiqaradi. Pastga tortib (pull-to-refresh) yangilanadi.
class CenterAbsenteesTab extends StatelessWidget {
  const CenterAbsenteesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = putOnce(
          () => CenterAbsenteesController(),
      tag: 'center_absentees_all',
    );

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        );
      }

      if (controller.summaries.isEmpty) {
        return RefreshIndicator(
          color: const Color(0xFF10B981),
          onRefresh: controller.loadData,
          child: ListView(
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
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emoji_events_outlined,
                            size: 40, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Bugun hamma davomatda!",
                        style: TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Hozircha kelmagan o'quvchi yo'q",
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        color: const Color(0xFF10B981),
        onRefresh: controller.loadData,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: controller.summaries.length,
          itemBuilder: (context, index) {
            final s = controller.summaries[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Get.to(() => GroupAbsenteesDetailView(
                  groupId: s.groupId,
                  groupName: s.groupName,
                  studentIds: s.absentStudentIds,
                  attendanceDocId: s.attendanceDocId, // YANGI
                )),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEEF2F6)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            const Color(0xFFDC2626).withOpacity(0.15),
                            const Color(0xFFDC2626).withOpacity(0.06),
                          ]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.person_off_rounded,
                            color: Color(0xFFDC2626), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.groupName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  fontSize: 15.5),
                            ),
                            // YANGI: guruh darajasida "Ogohlantirilgan"
                            // belgisi — bugun shu guruh uchun kamida
                            // bitta kishiga SMS yuborilgan bo'lsa ko'rinadi.
                            if (s.isNotified) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                                  SizedBox(width: 4),
                                  Text("Ogohlantirilgan", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${s.absentCount} kishi",
                          style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 4),
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
    });
  }
}