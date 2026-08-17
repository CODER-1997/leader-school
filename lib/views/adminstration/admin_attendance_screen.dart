import '../../controllers/admin_controller/admin_attendance_controller.dart';
 import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/get_helper.dart';


class AdminAttendanceScreen extends StatelessWidget {
  const AdminAttendanceScreen({super.key});

  Color _percentColor(double percent) {
    if (percent >= 80) return const Color(0xFF10B981);
    if (percent >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final controller = putOnce(() => AdminAttendanceController(), tag: 'admin_attendance');

    return Obx(() {
      if (controller.isLoading.value && controller.classSummaries.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5));
      }

      final summaries = controller.classSummaries;

      return RefreshIndicator(
        color: const Color(0xFF10B981),
        onRefresh: controller.refresh,
        child: summaries.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            Center(child: Text("Hozircha sinflar yo'q", style: TextStyle(color: Color(0xFF94A3B8)))),
          ],
        )
            : ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: summaries.length,
          itemBuilder: (context, index) {
            final s = summaries[index];
            final color = _percentColor(s.percent);
            final hasData = s.totalCount > 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEF2F6)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.class_rounded, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.className,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasData ? "${s.presentCount}/${s.totalCount} o'quvchi kelgan" : "Ma'lumot hali ulanmagan",
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    hasData ? "${s.percent.toStringAsFixed(0)}%" : "—",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: hasData ? color : const Color(0xFFCBD5E1)),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}