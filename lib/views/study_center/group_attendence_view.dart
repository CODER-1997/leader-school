import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/center/attendance_controller.dart';
import '../../controllers/center/center_student_controller.dart';
import '../school/student_profil/student_profil.dart';

/// Guruh ichidagi Davomat tabi — uzoq bosish TANLASH REJIMINI yoqadi
/// (raqamli doira ✓ belgiga aylanadi), shundan keyin XOHLAGAN qadar
/// qo'shimcha o'quvchini oddiy bosib tanlash/bekor qilish mumkin.
/// Tanlash rejimida EMASKAN — oddiy bosish StudentProfileView'ni ochadi.
///
/// Maktabda ham o'qiydigan o'quvchi uchun kichik "Maktab o'quvchisi"
/// belgisi ko'rsatiladi.
///
/// YANGI: pastga tortib (pull-to-refresh) ro'yxatni qayta yuklash —
/// GroupStudentsController.refresh() (allaqachon mavjud) orqali.
class GroupAttendanceTabScreen extends StatelessWidget {
  final GroupStudentsController controller;
  final String groupId;
  final String subjectId;
  final CenterSmsService selectionController;
  final void Function(Map<String, dynamic> student) onLongPressStudent;

  const GroupAttendanceTabScreen({
    super.key,
    required this.controller,
    required this.groupId,
    required this.subjectId,
    required this.selectionController,
    required this.onLongPressStudent,
  });

  String _capitalize(String text) {
    if (text.isEmpty) return '';
    return text.trim().split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
      }

      final students = controller.classStudents;


      // YANGI: RefreshIndicator endi HAR IKKALA holatni ham (bo'sh va
      // to'la) o'z ichiga oladi — bo'sh holatda ham pastga tortib
      // yangilash ishlashi uchun AlwaysScrollableScrollPhysics bilan.
      return RefreshIndicator(
        color: const Color(0xFF10B981),
        onRefresh: controller.refresh,
        child: students.isEmpty
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
                      child: const Icon(Icons.groups_outlined, size: 40, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(height: 16),
                    const Text("Guruhda o'quvchilar yo'q", style: TextStyle(color: Color(0xFF334155), fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text("Pastdagi tugma orqali qo'shing", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        )
            : () {
          // 1. Saralash ListView.builder'dan oldin BİR MARTA bajariladi
          final sortedStudents = List<Map<String, dynamic>>.from(students)..sort((a, b) {
            final String lastNameA = _capitalize(a['lastName'] ?? '');
            final String firstNameA = _capitalize(a['firstName'] ?? '');
            final String nameA = (lastNameA.isNotEmpty && firstNameA.isNotEmpty
                ? "$lastNameA $firstNameA"
                : _capitalize(a['name'] ?? 'Nomsiz')).trim().toLowerCase();

            final String lastNameB = _capitalize(b['lastName'] ?? '');
            final String firstNameB = _capitalize(b['firstName'] ?? '');
            final String nameB = (lastNameB.isNotEmpty && firstNameB.isNotEmpty
                ? "$lastNameB $firstNameB"
                : _capitalize(b['name'] ?? 'Nomsiz')).trim().toLowerCase();

            return nameA.compareTo(nameB);
          });

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: sortedStudents.length, // 2. Uzunlik saralangan ro'yxatdan olinadi
            itemBuilder: (context, index) {
              // 3. Har bir student saralangan ro'yxatdan olinadi
              final student = sortedStudents[index];
              final studentId = student['id'];

              final String lastName = _capitalize(student['lastName'] ?? '');
              final String firstName = _capitalize(student['firstName'] ?? '');
              final String displayName = lastName.isNotEmpty && firstName.isNotEmpty
                  ? "$lastName $firstName"
                  : _capitalize(student['name'] ?? 'Nomsiz');

              final bool isPrivileged = student['isPrivileged'] == true;
              final bool isSchoolStudent = (student['classId'] as String?)?.isNotEmpty == true;

              return Obx(() {
                final bool inSelectionMode = selectionController.selectionMode.value;
                final bool isSelected = selectionController.selectedIds.contains(studentId);

                return GestureDetector(
                  onLongPress: () {
                    if (!inSelectionMode) {
                      onLongPressStudent(student);
                    } else {
                      selectionController.toggle(studentId);
                    }
                  },
                  child: InkWell(
                    onTap: inSelectionMode
                        ? () => selectionController.toggle(studentId)
                        : () => Get.to(() => StudentProfileView(
                      studentId: studentId,
                      subjectId: groupId,
                      studentName: displayName,
                      fromCenterContext: true,
                      centerSubjectId: subjectId,
                    )),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF10B981).withOpacity(0.07) : Colors.white,
                        border: Border(
                          bottom: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                          left: BorderSide(color: isSelected ? const Color(0xFF10B981) : Colors.transparent, width: 3),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: inSelectionMode
                                ? Center(child: _SelectionIndicator(isSelected: isSelected))
                                : Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  backgroundColor: isPrivileged ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                                  child: Text(
                                    "${index + 1}",
                                    style: TextStyle(color: isPrivileged ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (isPrivileged)
                                  const Positioned(top: -4, right: -4, child: Icon(Icons.star_rounded, size: 18, color: Color(0xFFD97706))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                ),
                                if (isSchoolStudent) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.school_rounded, size: 10, color: Color(0xFF3B82F6)),
                                            SizedBox(width: 3),
                                            Text("Maktab o'quvchisi", style: TextStyle(fontSize: 10, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Obx(() {
                            final isPresent = controller.attendanceMap[studentId];
                            return Row(
                              children: [
                                _btn("Bor", isPresent == true, const Color(0xFF15803D), () => controller.toggleAttendance(studentId, true)),
                                const SizedBox(width: 8),
                                _btn("Yo'q", isPresent == false, const Color(0xFFB91C1C), () => controller.toggleAttendance(studentId, false)),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                );
              });
            },
          );
        }(),
      );
    });
  }

  Widget _btn(String label, bool isSelected, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(color: isSelected ? color : color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : color)),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  final bool isSelected;
  const _SelectionIndicator({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? const Color(0xFF10B981) : Colors.white,
        border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1), width: 2),
        boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))] : null,
      ),
      child: AnimatedScale(
        scale: isSelected ? 1 : 0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      ),
    );
  }
}