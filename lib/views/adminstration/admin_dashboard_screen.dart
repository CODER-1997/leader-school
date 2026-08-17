import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller/admin_controller.dart';
import '../../services/get_helper.dart';




class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = putOnce(() => AdminDashboardController(), tag: 'admin_dashboard');

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5));
      }

      return RefreshIndicator(
        color: const Color(0xFF10B981),
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _StatCard(
                  icon: Icons.class_outlined,
                  color: const Color(0xFF10B981),
                  label: "Jami sinflar",
                  value: "${controller.totalClasses.value}",
                ),
                _StatCard(
                  icon: Icons.groups_outlined,
                  color: const Color(0xFF3B82F6),
                  label: "Jami o'quvchilar",
                  value: "${controller.totalStudents.value}",
                ),
                _StatCard(
                  icon: Icons.fact_check_outlined,
                  color: const Color(0xFFF59E0B),
                  label: "Bugungi davomat",
                  value: "${controller.todayAttendancePercent.value}%",
                ),
                _StatCard(
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF8B5CF6),
                  label: "Oylik tushum",
                  value: "${controller.monthlyRevenue.value.toStringAsFixed(0)} so'm",
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Bu bo'lim hozircha skelet holatida. O'quvchilar soni, "
                          "davomat foizi va oylik tushum hali haqiqiy ma'lumotlarga "
                          "ulanmagan — controller ichidagi TODO izohlarga qarang.",
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E), height: 1.4),
                    ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF2F6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}