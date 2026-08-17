import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leader_school/views/school/school_view.dart';
import 'package:leader_school/views/study_center/center_view.dart';

import '../controllers/admin_controller/admin_auth_gate.dart';
import '../controllers/auth_home/auth_home_controller.dart';
import '../services/app_roles.dart';
import '../services/get_helper.dart';
import '../widgets/custom_card.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeViewController controller = putOnce(() => HomeViewController(), tag: 'home');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Custom Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Xush kelibsiz 👋",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Boshqaruv Paneli",
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.indigo.withOpacity(0.1),
                                child: const Icon(Icons.person, color: Colors.indigo),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          // 1. Maktab Bo'limi — Admin VA Teacher uchun ochiq
                          // (avval faqat admin uchun edi, shu sababli ustoz
                          // muvaffaqiyatli kirsa ham sinflarga kira olmasdi).
                          Obx(() => CustomCard(
                            title: 'Maktab',
                            subtitle: 'Sinflar va fanlar nazorati',
                            icon: Icons.school_rounded,
                            iconColor: const Color(0xFF3B82F6),
                            isLocked: controller.userRole.value.isEmpty,
                            onTap: () {
                              if (controller.userRole.value.isNotEmpty) {
                                Get.to(const SchoolView());
                              } else {
                                Get.snackbar(
                                  "Ruxsat yo'q",
                                  "Avval maxsus kod bilan kiring!",
                                  backgroundColor: Colors.orange,
                                  colorText: Colors.white,
                                );
                              }
                            },
                          )),

                          const SizedBox(height: 16),

                          // 2. O'quv Markaz Bo'limi — Admin VA Teacher uchun ochiq
                          Obx(() => CustomCard(
                            title: 'O\'quv Markaz',
                            subtitle: 'Guruhlar va to\'lovlar',
                            icon: Icons.business_center_rounded,
                            iconColor: const Color(0xFF10B981),
                            isLocked: controller.userRole.value.isEmpty,
                            onTap: () {
                              if (controller.userRole.value.isNotEmpty) {
                                Get.to(const CenterView());
                              } else {
                                Get.snackbar(
                                  "Ruxsat yo'q",
                                  "Avval maxsus kod bilan kiring!",
                                  backgroundColor: Colors.orange,
                                  colorText: Colors.white,
                                );
                              }
                            },
                          )),

                          const SizedBox(height: 16),

                          // 3. Admin Card — FAQAT admin uchun (o'zgarishsiz)
                          Obx(() => controller.userRole.value == AppRoles.admin
                              ? Column(
                            children: [
                              CustomCard(
                                title: 'Admin Paneli',
                                subtitle: 'To\'liq boshqaruv va sozlamalar',
                                icon: Icons.admin_panel_settings_rounded,
                                iconColor: const Color(0xFF8B5CF6),
                                isLocked: false,
                                onTap: () {
                                  Get.to(const AdminAuthGate());
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                          )
                              : const SizedBox.shrink()),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Pastdagi Kirish / Chiqish tugmasi
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: Obx(() => ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: controller.userRole.value.isNotEmpty
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: () => showBottomModalLogin(context, controller),
                          child: Text(
                            controller.userRole.value.isNotEmpty ? "Chiqish" : "Kirish",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )),
                      ),
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

  // --- Pastdan chiqadigan Modal (BottomSheet) ---
  void showBottomModalLogin(BuildContext context, HomeViewController controller) {
    // Foydalanuvchi allaqachon kirgan bo'lsa -> Chiqish tasdiqlash oynasi
    if (controller.userRole.value.isNotEmpty) {
      Get.bottomSheet(
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "Tizimdan chiqish",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Haqiqatan ham tizimdan chiqmoqchimisiz?",
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Get.back(),
                        child: const Text(
                          "Bekor qilish",
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          controller.logout();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Chiqish",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        isScrollControlled: true,
      );
      return;
    }

    // Foydalanuvchi kirmagan bo'lsa -> Kod kiritish oynasi
    controller.roleIdController.clear();
    controller.isObscured.value = true;

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.lock_rounded, color: Color(0xFF3B82F6), size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "Maxsus Kod",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Tizimga kirish uchun maxsus kodni kiriting.",
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),

              Obx(() => TextField(
                controller: controller.roleIdController,
                obscureText: controller.isObscured.value,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Kodni kiriting...",
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.isObscured.value ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () => controller.isObscured.value = !controller.isObscured.value,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                  ),
                ),
              )),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Obx(() => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: controller.isChecking.value ? null : () async {
                    final bool success = await controller.checkAccessCode();
                    if (success && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: controller.isChecking.value
                      ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                      : const Text(
                    "Tasdiqlash",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                )),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}