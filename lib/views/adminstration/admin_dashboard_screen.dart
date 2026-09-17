import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/get_helper.dart';
import 'admin_archived_students_screen.dart'; // YANGI

/// Boshqaruv paneli — ASTA-SEKIN quriladi. Hozircha faqat "Arxiv"
/// qismi ishlaydi (o'chirilgan o'quvchilar statistikasi). Boshqa
/// bo'limlar (sinflar, davomat, tushum) keyinroq qo'shiladi.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.construction_rounded, color: Color(0xFFD97706), size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Boshqaruv paneli asta-sekin quriladi — hozircha faqat Arxiv bo'limi ishlaydi.",
                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.3),
                ),
              ),
            ],
          ),
        ),

        // --- ARXIV KARTASI ---
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Get.to(() => const AdminArchivedStudentsScreen()),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEEF2F6)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF64748B), Color(0xFF475569)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Arxiv", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                      SizedBox(height: 3),
                      Text("O'chirilgan o'quvchilar statistikasi", style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}