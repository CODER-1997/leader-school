import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/admin_controller/admin_archived_students_controller.dart'; // MUHIM: sizning haqiqiy yo'lingizga moslang
import '../../services/get_helper.dart';

/// Sabab kalitlari — student_profil.dart'dagi _archiveReasons bilan
/// AYNAN bir xil (label/icon mos kelishi uchun).
const Map<String, Map<String, dynamic>> _reasonMeta = {
  'graduated': {'label': "Bitirdi", 'icon': Icons.school_rounded, 'color': Color(0xFF10B981)},
  'enrolled_elsewhere': {'label': "O'qishga kirdi", 'icon': Icons.emoji_events_rounded, 'color': Color(0xFF3B82F6)},
  'expelled': {'label': "Haydaldi", 'icon': Icons.gavel_rounded, 'color': Color(0xFFDC2626)},
  'financial': {'label': "Moliyaviy sharoitlar", 'icon': Icons.payments_rounded, 'color': Color(0xFFD97706)},
  'family': {'label': "Oilaviy sharoit", 'icon': Icons.home_rounded, 'color': Color(0xFF8B5CF6)},
  'unknown': {'label': "Noma'lum", 'icon': Icons.help_outline_rounded, 'color': Color(0xFF94A3B8)},
};

class AdminArchivedStudentsScreen extends StatelessWidget {
  const AdminArchivedStudentsScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final controller = putOnce(() => AdminArchivedStudentsController(), tag: 'admin_archived_students');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Arxiv", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: Obx(() {
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

        final students = controller.archivedStudents;

        if (students.isEmpty) {
          return RefreshIndicator(
            color: const Color(0xFF10B981),
            onRefresh: controller.refresh,
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
                          decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), shape: BoxShape.circle),
                          child: const Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF10B981)),
                        ),
                        const SizedBox(height: 16),
                        const Text("Arxiv bo'sh", style: TextStyle(color: Color(0xFF334155), fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text("Hozircha o'chirilgan o'quvchilar yo'q", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
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
          onRefresh: controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // --- JAMI SONI ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF64748B), Color(0xFF475569)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Jami arxivlangan", style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Text("${controller.totalArchived} ta o'quvchi", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- SABAB BO'YICHA TAQSIMOT ---
              const Text("Sabab bo'yicha", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: _reasonMeta.entries.where((e) => e.key != 'unknown' || (controller.countsByReason['unknown'] ?? 0) > 0).map((entry) {
                  final meta = entry.value;
                  final count = controller.countsByReason[entry.key] ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEEF2F6)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: (meta['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(meta['icon'] as IconData, color: meta['color'] as Color, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("$count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A))),
                              Text(meta['label'] as String, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // --- RO'YXAT ---
              const Text("Arxivlangan o'quvchilar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
              const SizedBox(height: 10),
              ...students.map((s) {
                final reasonKey = s['archivedReason'] as String;
                final meta = _reasonMeta[reasonKey] ?? _reasonMeta['unknown']!;
                final archivedAt = s['archivedAt'] as DateTime?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEF2F6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: (meta['color'] as Color).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                        child: Icon(meta['icon'] as IconData, color: meta['color'] as Color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_fullName(s), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B))),
                            const SizedBox(height: 2),
                            Text(
                              archivedAt != null
                                  ? "${meta['label']} · ${DateFormat('dd.MM.yyyy').format(archivedAt)}"
                                  : meta['label'] as String,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }),
    );
  }
}