import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Har bir sinf uchun admin ko'radigan qisqacha davomat ma'lumoti.
class ClassAttendanceSummary {
  final String classId;
  final String className;
  // TODO(Bek): quyidagi ikkisi hozircha placeholder — haqiqiy attendance
  // data modelingizga ulaganda to'ldiriladi (masalan bugungi sana bo'yicha
  // "bor"/"yo'q" hisoblanadi).
  final int presentCount;
  final int totalCount;

  ClassAttendanceSummary({
    required this.classId,
    required this.className,
    this.presentCount = 0,
    this.totalCount = 0,
  });

  double get percent => totalCount == 0 ? 0 : (presentCount / totalCount) * 100;
}

/// Admin uchun BARCHA sinflarning davomat holatini bir joyda ko'rsatadi.
/// Sinflar ro'yxati REAL — 'school_classes' collection'idan olinadi
/// (bitta equality/oddiy query, index kerak emas, kichik collection —
/// real-time listener bilan xavfsiz).
class AdminAttendanceController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var isLoading = true.obs;
  var classSummaries = <ClassAttendanceSummary>[].obs;

  StreamSubscription<QuerySnapshot>? _sub;

  @override
  void onInit() {
    super.onInit();
    _attachListener();
  }

  void _attachListener() {
    _sub?.cancel();
    _sub = _db
        .collection('school_classes')
        .orderBy('name')
        .snapshots()
        .listen(_onSnapshot, onError: (e) {
      debugPrint("Admin attendance listener xatosi: $e");
      isLoading.value = false;
    });
  }

  void _onSnapshot(QuerySnapshot snap) {
    classSummaries.value = snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return ClassAttendanceSummary(
        classId: doc.id,
        className: data['name'] ?? 'Nomsiz sinf',
        // TODO(Bek): haqiqiy bugungi davomat sonlarini shu yerga ulang
        // (masalan har bir sinf uchun subject'lar bo'yicha attendanceMap
        // yig'indisi). Hozircha 0/0 — kartada "—" ko'rinadi.
        presentCount: 0,
        totalCount: 0,
      );
    }).toList();
    isLoading.value = false;
  }

  Future<void> refresh() async {
    _attachListener();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}