import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/admin_controller/admin_attendance_controller.dart';
import '../../controllers/admin_controller/admin_controller.dart';
import '../../controllers/admin_controller/admin_payment_controller.dart';
import '../../controllers/admin_controller/admin_security_controller.dart';
import '../../controllers/admin_controller/admin_settings_controller.dart';
import '../../controllers/admin_controller/admin_teacher_controller.dart';
import 'admin_dashboard_screen.dart';
import 'admin_attendance_screen.dart';
import 'admin_payment_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_teacher_screen.dart';

/// ADMIN BO'LIMI — bottom navigation bilan 5 ta asosiy oyna.
///
/// IKKITA MUHIM QOIDA:
///
/// 1. LAZY LOADING: har bir tab faqat FOYDALANUVCHI birinchi marta o'sha
///    tabga bosganda quriladi (va shu bilan uning controlleri/Firestore
///    so'rovi/listeneri ishga tushadi). Tashrif buyurmagan tab hech qanday
///    read hosil qilmaydi. Bir marta qurilgan tab keyin IndexedStack orqali
///    state'ini saqlab qoladi (qayta qurilmaydi).
///
/// 2. TOZALASH: bu ekrandan butunlay chiqilganda (masalan foydalanuvchi
///    admin panelni yopib ketsa), BARCHA admin controllerlar — jumladan
///    AdminAttendanceController'dagi real-time Firestore listener —
///    to'liq to'xtatiladi. Aks holda listener fonda abadiy ishlab, Firestore
///    read sonini asossiz oshiraveradi.
class AdminMainView extends StatefulWidget {
  const AdminMainView({super.key});

  @override
  State<AdminMainView> createState() => _AdminMainViewState();
}

class _AdminMainViewState extends State<AdminMainView> {
  int _currentIndex = 0;

  // Faqat foydalanuvchi tashrif buyurgan tab indekslari shu to'plamda —
  // shu orqali qaysi ekranlar HAQIQATAN qurilishi kerakligini bilamiz.
  final Set<int> _visitedTabs = {0};

  static const _titles = [
    "Boshqaruv paneli",
    "Davomat nazorati",
    "O'qituvchilar",
    "To'lovlar",
    "Sozlamalar",
  ];

  Widget _buildTab(int index) {
    // Hali tashrif buyurilmagan tab uchun HECH QANDAY controller
    // yaratilmaydi — faqat arzon, bo'sh placeholder qaytariladi.
    if (!_visitedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return const AdminDashboardScreen();
      case 1:
        return const AdminAttendanceScreen();
      case 2:
        return const AdminTeachersScreen();
      case 3:
        return const AdminPaymentsScreen();
      case 4:
        return const AdminSettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index); // shu tabni endi "qurish kerak" deb belgilaymiz
    });
  }

  @override
  void dispose() {
    // MUHIM: admin panelidan butunlay chiqilganda barcha admin
    // controllerlarni (va ular ichidagi real-time listenerlarni) to'liq
    // to'xtatamiz. Bu chaqirilmasa, masalan AdminAttendanceController'dagi
    // 'school_classes' listeneri foydalanuvchi admin panelni yopib
    // ketgandan keyin ham FONDA ABADIY ishlab, keraksiz Firestore
    // read'lar hosil qilib turaveradi.
    if (Get.isRegistered<AdminDashboardController>(tag: 'admin_dashboard')) {
      Get.delete<AdminDashboardController>(tag: 'admin_dashboard');
    }
    if (Get.isRegistered<AdminAttendanceController>(tag: 'admin_attendance')) {
      Get.delete<AdminAttendanceController>(tag: 'admin_attendance');
    }
    if (Get.isRegistered<AdminTeacherController>(tag: 'admin_teachers')) {
      Get.delete<AdminTeacherController>(tag: 'admin_teachers');
    }
    if (Get.isRegistered<AdminPaymentsController>(tag: 'admin_payments')) {
      Get.delete<AdminPaymentsController>(tag: 'admin_payments');
    }
    if (Get.isRegistered<AdminSettingsController>(tag: 'admin_settings')) {
      Get.delete<AdminSettingsController>(tag: 'admin_settings');
    }
    if (Get.isRegistered<AdminSecurityController>(tag: 'admin_security')) {
      Get.delete<AdminSecurityController>(tag: 'admin_security');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(5, _buildTab),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF10B981).withOpacity(0.12),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: Color(0xFF94A3B8)),
            selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFF10B981)),
            label: "Bosh sahifa",
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined, color: Color(0xFF94A3B8)),
            selectedIcon: Icon(Icons.fact_check_rounded, color: Color(0xFF10B981)),
            label: "Davomat",
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined, color: Color(0xFF94A3B8)),
            selectedIcon: Icon(Icons.people_alt_rounded, color: Color(0xFF10B981)),
            label: "O'qituvchilar",
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined, color: Color(0xFF94A3B8)),
            selectedIcon: Icon(Icons.payments_rounded, color: Color(0xFF10B981)),
            label: "To'lovlar",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: Color(0xFF94A3B8)),
            selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF10B981)),
            label: "Sozlamalar",
          ),
        ],
      ),
    );
  }
}