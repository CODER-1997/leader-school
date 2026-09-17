import 'package:flutter/material.dart';
import 'package:get/get.dart';

 import '../../controllers/school_absentees_controller.dart';
import 'class_subject_absentees_detail_view.dart';

/// "Kelmaganlar" — 2-BOSQICH: bitta SINF ichida, bugun kelmagani bor
/// FANLAR ro'yxati. Qo'shimcha Firestore so'rovi kerak EMAS — ma'lumot
/// allaqachon SchoolAbsenteesController.classSummaries orqali tayyor
/// uzatiladi. Fan ustiga bosilsa — ClassSubjectAbsenteesDetailView'ga
/// (3-bosqich, o'quvchilar ro'yxati) o'tiladi.
class ClassAbsentSubjectsView extends StatelessWidget {
  final String classId;
  final String className;
  final List<ClassSubjectAbsenteeSummary> subjects;

  const ClassAbsentSubjectsView({
    super.key,
    required this.classId,
    required this.className,
    required this.subjects,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(className, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: subjects.length,
          itemBuilder: (context, index) {
            final s = subjects[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Get.to(() => ClassSubjectAbsenteesDetailView(
                  classId: s.classId,
                  subjectId: s.subjectId,
                  displayTitle: s.displayTitle,
                  studentIds: s.absentStudentIds,
                  attendanceDocId: s.attendanceDocId,
                )),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEEF2F6)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.menu_book_rounded, color: Color(0xFF3B82F6), size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 15)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text("${s.absentCount} kishi", style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}