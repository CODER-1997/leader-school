import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/payment_stats_service.dart';


/// Boshqaruv panelining umumiy statistikasi.
/// Bu controller BOSHQA controllerlarning (Attendance/Teachers/Payments)
/// engil xulosalarini bir joyga jamlaydi — og'ir hisob-kitoblarni o'zi
/// qilmaydi, faqat kichik "count" so'rovlarini yuboradi.
class AdminDashboardController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var isLoading = true.obs;

  var totalClasses = 0.obs;
  var totalStudents = 0.obs;
  var todayAttendancePercent = 0.obs; // 0-100
  var monthlyRevenue = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    isLoading.value = true;
    try {
      // Sinflar soni — arzon, chunki .count() faqat 1 ta hisoblash o'qishi
      // sifatida hisoblanadi (hujjatlarning o'zini yuklamaydi).
      final classesAgg = await _db.collection('school_classes').count().get();
      totalClasses.value = classesAgg.count ?? 0;

      // TODO(Bek): O'quvchilar umumiy soni — haqiqiy manbaga moslang.
      // Agar har bir sinf o'zining "count" maydonini saqlasa (SchoolController
      // buni tayyorlagan edi), collectionGroup so'rov shart emas — shu
      // maydonlarni yig'ish kifoya. Hozircha placeholder sifatida 0.
      totalStudents.value = 0;

      // TODO(Bek): Bugungi davomat foizi — sizning attendance data
      // modelingizga bog'liq (masalan subjectlar ichida attendanceMap
      // saqlanadi). Bu yerga real hisoblash ulanadi.
      todayAttendancePercent.value = 0;

      // Oylik tushum — endi PaymentStatsService orqali, BITTA hujjat
      // o'qishi bilan (necha ming to'lov bo'lishidan qat'i nazar).
      monthlyRevenue.value = await PaymentStatsService.fetchCurrentMonthTotal();
    } catch (e) {
      debugPrint("Dashboard statistikasini yuklashda xato: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => _loadSummary();
}