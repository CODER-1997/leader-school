import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/current_user_permission.dart';
import '../crm_controller.dart'; // YANGI: MUHIM — haqiqiy yo'lingizga moslang
import '../subject_student_controller.dart'; // YANGI: MUHIM — haqiqiy yo'lingizga moslang (Maktab ro'yxati)
import '../center/center_student_controller.dart'; // YANGI: MUHIM — haqiqiy yo'lingizga moslang (Markaz ro'yxati, GroupStudentsController shu yerda)


class StudentProfileController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String studentId;
  final String subjectId;

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController phoneController;
  late TextEditingController parentPhoneController;

  var isPrivileged = false.obs;
  var isLoading = true.obs;
  var subjectName = "".obs;

  var canViewPayments = false.obs;
  var canEditPayments = false.obs;
  var isLoadingPermissions = true.obs;

  Future<void> _loadPermissions() async {
    isLoadingPermissions.value = true;
    canViewPayments.value = await CurrentUserPermissions.canViewPayments();
    canEditPayments.value = await CurrentUserPermissions.canEditPayments();
    isLoadingPermissions.value = false;
  }

  var hasSchoolClass = false.obs;

  var centerSubjectJoinDates = <String, DateTime>{}.obs;

  DateTime? subjectJoinedAt(String subjectId) => centerSubjectJoinDates[subjectId];

  var centerGroupIds = <String>[].obs;
  var centerGroupNames = <Map<String, String>>[].obs;
  var isLoadingGroupNames = false.obs;

  String? _classId;
  // YANGI: tashqaridan (masalan sinf tahrirlash dialogidan) joriy
  // classId'ni o'qish uchun ochiq getter.
  String? get classId => _classId;
  var schoolAttendancePercent = Rxn<double>();
  var schoolAttendanceSample = 0.obs;
  var centerAttendanceByGroup = <Map<String, dynamic>>[].obs;
  var isLoadingAttendanceSummary = false.obs;

  var attendanceMapsBySource = <String, Map<String, bool>>{}.obs;

  String _dateKey(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  // =========================================================================
  // YANGI: 'students' ustidagi HAR QANDAY yozuvdan keyin (arxivlash,
  // guruh o'zgartirish, ism-familiya tahrirlash) chaqiriladi.
  //
  // MUHIM (2-QAVAT TUZATISH): faqat CrmController.allStudents'ni
  // yangilashning O'ZI YETARLI EMAS EKAN — chunki SubjectStudentsController
  // (Maktab) VA GroupStudentsController (Markaz) o'zlarining classStudents
  // ro'yxatini CrmController'dan BIR MARTALIK NUSXA sifatida oladi (onInit
  // paytida) va keyin CrmController bilan hech qanday bog'liqligi qolmaydi.
  // Shuning uchun, agar foydalanuvchi HOZIR o'sha ro'yxatdan profilga
  // o'tgan bo'lsa (demak controller hali GetX'da RO'YXATDAN O'TGAN —
  // "tag: subjectId" bilan), o'sha ANIQ controllerning nusxasini ham
  // TO'G'RIDAN-TO'G'RI yangilaymiz. `subjectId` — School kontekstida
  // haqiqiy fan ID'si, Markaz kontekstida esa GURUH ID'si sifatida
  // ishlatiladi (StudentProfileView shunday uzatadi) — shuning uchun
  // IKKALASINI HAM tag sifatida sinab ko'ramiz.
  // =========================================================================
  void _patchCrmCache(Map<String, dynamic> changes) {
    if (Get.isRegistered<CrmController>()) {
      final crm = Get.find<CrmController>();
      final idx = crm.allStudents.indexWhere((s) => s['id'] == studentId);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(crm.allStudents[idx]);
        updated.addAll(changes);
        crm.allStudents[idx] = updated;
      }
    }

    if (Get.isRegistered<SubjectStudentsController>(tag: subjectId)) {
      final ctrl = Get.find<SubjectStudentsController>(tag: subjectId);
      final idx = ctrl.classStudents.indexWhere((s) => s['id'] == studentId);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(ctrl.classStudents[idx]);
        updated.addAll(changes);
        ctrl.classStudents[idx] = updated;
      }
    }

    if (Get.isRegistered<GroupStudentsController>(tag: subjectId)) {
      final ctrl = Get.find<GroupStudentsController>(tag: subjectId);
      final idx = ctrl.classStudents.indexWhere((s) => s['id'] == studentId);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(ctrl.classStudents[idx]);
        updated.addAll(changes);
        ctrl.classStudents[idx] = updated;
      }
    }
  }

  /// Arxivlangan o'quvchi endi hech qanday faol sinf/guruhga tegishli
  /// emas — uni HAMMA joriy nusxalardan (global kesh + faol ro'yxat
  /// controlleri) BUTUNLAY OLIB TASHLAYMIZ.
  void _removeFromCrmCache() {
    if (Get.isRegistered<CrmController>()) {
      Get.find<CrmController>().allStudents.removeWhere((s) => s['id'] == studentId);
    }
    if (Get.isRegistered<SubjectStudentsController>(tag: subjectId)) {
      Get.find<SubjectStudentsController>(tag: subjectId).classStudents.removeWhere((s) => s['id'] == studentId);
    }
    if (Get.isRegistered<GroupStudentsController>(tag: subjectId)) {
      Get.find<GroupStudentsController>(tag: subjectId).classStudents.removeWhere((s) => s['id'] == studentId);
    }
  }

  Future<void> loadFullAttendanceSummary() async {
    if (isLoadingAttendanceSummary.value) return;
    isLoadingAttendanceSummary.value = true;
    try {
      final cutoff = _dateKey(DateTime.now().subtract(const Duration(days: 60)));
      final Map<String, Map<String, bool>> mapsBySource = {};

      if (_classId != null && _classId!.isNotEmpty) {
        final snap = await _db
            .collection('attendance')
            .where('classId', isEqualTo: _classId)
            .where('date', isGreaterThanOrEqualTo: cutoff)
            .get();
        int present = 0, total = 0;
        final Map<String, bool> dayMap = {};
        for (final doc in snap.docs) {
          final data = doc.data();
          final records = Map<String, dynamic>.from(data['records'] ?? {});
          if (records.containsKey(studentId)) {
            total++;
            final isPresent = records[studentId] == true;
            if (isPresent) present++;
            dayMap[data['date'] as String] = isPresent;
          }
        }
        schoolAttendancePercent.value = total > 0 ? (present / total * 100) : null;
        schoolAttendanceSample.value = total;
        mapsBySource['school'] = dayMap;
      }

      final List<Map<String, dynamic>> centerResults = [];
      for (final groupId in centerGroupIds) {
        final snap = await _db
            .collection('attendance')
            .where('subjectId', isEqualTo: groupId)
            .where('date', isGreaterThanOrEqualTo: cutoff)
            .get();
        int present = 0, total = 0;
        final Map<String, bool> dayMap = {};
        for (final doc in snap.docs) {
          final data = doc.data();
          final records = Map<String, dynamic>.from(data['records'] ?? {});
          if (records.containsKey(studentId)) {
            total++;
            final isPresent = records[studentId] == true;
            if (isPresent) present++;
            dayMap[data['date'] as String] = isPresent;
          }
        }
        if (total > 0) {
          final groupInfo = centerGroupNames.firstWhereOrNull((g) => g['id'] == groupId);
          centerResults.add({
            'groupId': groupId,
            'name': groupInfo?['name'] ?? 'Guruh',
            'percent': present / total * 100,
            'sample': total,
          });
          mapsBySource[groupId] = dayMap;
        }
      }
      centerAttendanceByGroup.value = centerResults;
      attendanceMapsBySource.value = mapsBySource;
    } catch (e) {
      debugPrint("To'liq davomat xulosasini yuklashda xato: $e");
    } finally {
      isLoadingAttendanceSummary.value = false;
    }
  }

  Future<void> _loadGroupNames(List<String> groupIds) async {
    if (groupIds.isEmpty) {
      centerGroupNames.value = [];
      return;
    }
    isLoadingGroupNames.value = true;
    try {
      final List<Map<String, String>> result = [];
      for (var i = 0; i < groupIds.length; i += 30) {
        final chunk = groupIds.skip(i).take(30).toList();
        final snap = await FirebaseFirestore.instance.collection('groups').where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in snap.docs) {
          final data = doc.data();
          result.add({
            'id': doc.id,
            'name': data['name'] ?? 'Nomsiz guruh',
            'subjectId': data['subjectId'] ?? '',
          });
        }
      }
      centerGroupNames.value = result;
    } catch (e) {
      debugPrint("Guruh nomlarini yuklashda xato: $e");
    } finally {
      isLoadingGroupNames.value = false;
    }
  }

  var attendanceHistory = <String, bool>{}.obs;

  StudentProfileController({required this.studentId, required this.subjectId});

  Future<void> refresh() => fetchStudentProfileData();

  Future<bool> archiveStudent(String reason) async {
    try {
      await _db.collection('students').doc(studentId).update({
        'isArchived': true,
        'archivedReason': reason,
        'archivedAt': FieldValue.serverTimestamp(),
        'classId': FieldValue.delete(),
        'centerGroupIds': [],
      });
      _removeFromCrmCache(); // YANGI: xotiradagi keshdan ham darhol olib tashlaymiz
      return true;
    } catch (e) {
      debugPrint("O'quvchini arxivlashda xato: $e");
      return false;
    }
  }

  Future<bool> updateGroupMembership({
    required List<String> newGroupIds,
    required Map<String, String> subjectIdByGroupId,
    required String? newClassId, // YANGI — null/bo'sh = maktabdan chiqariladi
  }) async {
    try {
      final Map<String, dynamic> updateData = {'centerGroupIds': newGroupIds};

      // YANGI: Maktab sinfini ham yangilaymiz.
      if (newClassId == null || newClassId.isEmpty) {
        updateData['classId'] = FieldValue.delete();
      } else {
        updateData['classId'] = newClassId;
      }

      final Set<String> newSubjectIds = newGroupIds.map((gId) => subjectIdByGroupId[gId] ?? '').where((s) => s.isNotEmpty).toSet();
      for (final subjId in newSubjectIds) {
        if (!centerSubjectJoinDates.containsKey(subjId)) {
          updateData['centerSubjectJoinDates.$subjId'] = Timestamp.fromDate(DateTime.now());
        }
      }

      await _db.collection('students').doc(studentId).update(updateData);

      centerGroupIds.value = newGroupIds;
      await _loadGroupNames(newGroupIds);
      for (final subjId in newSubjectIds) {
        centerSubjectJoinDates.putIfAbsent(subjId, () => DateTime.now());
      }

      // YANGI: lokal classId/hasSchoolClass holatini ham yangilaymiz.
      hasSchoolClass.value = newClassId != null && newClassId.isNotEmpty;
      _classId = hasSchoolClass.value ? newClassId : null;

      _patchCrmCache({
        'centerGroupIds': newGroupIds,
        'classId': hasSchoolClass.value ? newClassId : null,
      });

      return true;
    } catch (e) {
      debugPrint("Ma'lumotlarni yangilashda xato: $e");
      return false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    phoneController = TextEditingController();
    parentPhoneController = TextEditingController();
    fetchStudentProfileData();
    _loadPermissions();
  }

  Future<void> fetchStudentProfileData() async {
    try {
      isLoading.value = true;

      var studentDoc = await _db.collection('students').doc(studentId).get();
      if (studentDoc.exists) {
        var data = studentDoc.data()!;
        firstNameController.text = data['firstName'] ?? '';
        lastNameController.text = data['lastName'] ?? '';
        phoneController.text = data['phone'] ?? '';
        parentPhoneController.text = data['parentPhone'] ?? '';
        isPrivileged.value = data['isPrivileged'] ?? false;

        final classId = data['classId'];
        hasSchoolClass.value = classId != null && classId.toString().isNotEmpty;
        _classId = hasSchoolClass.value ? classId.toString() : null;

        final rawJoinDates = Map<String, dynamic>.from(data['centerSubjectJoinDates'] ?? {});
        centerSubjectJoinDates.value = rawJoinDates.map((key, value) {
          final ts = value as Timestamp?;
          return MapEntry(key, ts?.toDate() ?? DateTime.now());
        });

        centerGroupIds.value = List<String>.from(data['centerGroupIds'] ?? []);
        _loadGroupNames(centerGroupIds);
      }

      var subjectDoc = await _db.collection('subjects').doc(subjectId).get();
      if (subjectDoc.exists) {
        subjectName.value = subjectDoc.data()?['name'] ?? '';
      }

      var attendanceQuery = await _db.collection('attendance')
          .where('subjectId', isEqualTo: subjectId)
          .get();

      Map<String, bool> history = {};
      for (var doc in attendanceQuery.docs) {
        var data = doc.data();
        String dateStr = data['date'];

        if (data['records'] is Map) {
          var records = data['records'] as Map<String, dynamic>;
          if (records.containsKey(studentId)) {
            history[dateStr] = records[studentId] == true;
          }
        }
      }
      attendanceHistory.value = history;

    } catch (e) {
      debugPrint("Ma'lumotlarni yuklashda xato: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateStudentProfile() async {
    String firstName = firstNameController.text.trim();
    String lastName = lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      Get.snackbar("Diqqat", "Ism va familiyani kiriting!", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    try {
      final changes = {
        'firstName': firstName,
        'lastName': lastName,
        'name': "$firstName $lastName",
        'phone': phoneController.text.trim(),
        'parentPhone': parentPhoneController.text.trim(),
        'isPrivileged': isPrivileged.value,
      };

      await _db.collection('students').doc(studentId).update(changes);
      _patchCrmCache(changes); // YANGI: keshni ham yangilaymiz (aks holda ro'yxatlarda eski ism qolib ketardi)

      Get.snackbar("Muvaffaqiyatli", "O'quvchi ma'lumotlari yangilandi!", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xato", "Xatolik yuz berdi: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    parentPhoneController.dispose();
    super.onClose();
  }
}