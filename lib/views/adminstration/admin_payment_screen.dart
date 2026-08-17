 import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/admin_controller/admin_payment_controller.dart';
import '../../services/get_helper.dart';


class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});

  String _sourceLabel(String source) => source == 'tutoring' ? "Repetitorlik" : "Maktab";

  String _methodLabel(String method) {
    switch (method) {
      case 'card':
        return "Karta";
      case 'bank_transfer':
        return "Bank o'tkazmasi";
      default:
        return "Naqd";
    }
  }

  // YANGI: davr bo'yicha ommaviy qulflash. Tez tanlash (joriy oy, oxirgi
  // 3 kun) YOKI qo'lda sana oralig'i.
  Future<void> _showLockPeriodDialog(BuildContext context, AdminPaymentsController controller) async {
    DateTime? customStart;
    DateTime? customEnd;

    await Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          Future<void> _runLock(DateTime start, DateTime end, String label) async {
            Get.back();
            final count = await controller.lockPaymentsInRange(start: start, end: end);
            Get.snackbar(
              count > 0 ? "Qulflandi" : "O'zgarish yo'q",
              count > 0 ? "$label uchun $count ta to'lov qulflandi" : "$label uchun qulflanadigan to'lov topilmadi",
              backgroundColor: count > 0 ? const Color(0xFF10B981) : const Color(0xFF64748B),
              colorText: Colors.white,
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFD97706).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.lock_clock_rounded, color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text("Davrni yopish", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Tanlangan davrdagi BARCHA o'quvchilarning to'lovlari qulflanadi — buxgalter/o'qituvchi ularni endi tahrirlay olmaydi.",
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  _lockOptionTile(
                    icon: Icons.calendar_month_rounded,
                    label: "Joriy oy",
                    onTap: () {
                      final now = DateTime.now();
                      _runLock(DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0, 23, 59, 59), "Joriy oy");
                    },
                  ),
                  const SizedBox(height: 8),
                  _lockOptionTile(
                    icon: Icons.today_rounded,
                    label: "Oxirgi 3 kun",
                    onTap: () {
                      final now = DateTime.now();
                      _runLock(now.subtract(const Duration(days: 3)), now, "Oxirgi 3 kun");
                    },
                  ),
                  const SizedBox(height: 8),
                  _lockOptionTile(
                    icon: Icons.date_range_rounded,
                    label: customStart == null
                        ? "Boshqa davr tanlash..."
                        : "${DateFormat('dd.MM').format(customStart!)} – ${customEnd != null ? DateFormat('dd.MM').format(customEnd!) : '...'}",
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030),
                      );
                      if (range != null) {
                        setState(() {
                          customStart = range.start;
                          customEnd = range.end;
                        });
                      }
                    },
                  ),

                  if (customStart != null && customEnd != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        onPressed: () => _runLock(
                          customStart!,
                          DateTime(customEnd!.year, customEnd!.month, customEnd!.day, 23, 59, 59),
                          "${DateFormat('dd.MM.yyyy').format(customStart!)} – ${DateFormat('dd.MM.yyyy').format(customEnd!)}",
                        ),
                        child: const Text("Shu davrni qulflash", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(onPressed: () => Get.back(), child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF94A3B8)))),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _lockOptionTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF64748B)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)))),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = putOnce(() => AdminPaymentsController(), tag: 'admin_payments');
    final currencyFormat = NumberFormat("#,###", "uz");

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5));
      }

      final payments = controller.payments;

      return RefreshIndicator(
        color: const Color(0xFF10B981),
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Shu oy jami tushum", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    "${currencyFormat.format(controller.totalAmount.value)} so'm",
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: Obx(() => OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD97706)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: controller.isLocking.value ? null : () => _showLockPeriodDialog(context, controller),
                icon: controller.isLocking.value
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)))
                    : const Icon(Icons.lock_clock_rounded, size: 18, color: Color(0xFFD97706)),
                label: Text(
                  controller.isLocking.value ? "Qulflanmoqda..." : "Davrni yopish (qulflash)",
                  style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              )),
            ),

            const SizedBox(height: 20),
            const Text("So'nggi to'lovlar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),

            // YANGI: xato bo'lsa — nima uchun bo'sh ekanini ANIQ ko'rsatamiz
            // (avval bu holat "Hozircha to'lovlar topilmadi" bilan bir xil
            // ko'rinib, sababni bilib bo'lmasdi).
            if (controller.errorMessage.value != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFECACA))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        SizedBox(width: 8),
                        Text("To'lovlarni yuklashda xato", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      controller.errorMessage.value!,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Eng ehtimolli sabab: Firestore composite index yaratilmagan, YOKI xavfsizlik qoidalarida collectionGroup so'roviga ruxsat yo'q.",
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF991B1B)),
                    ),
                  ],
                ),
              )
            else if (payments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      const Text("Hozircha to'lovlar topilmadi", style: TextStyle(color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              )
            else
              ...payments.map((p) => Container(
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
                      decoration: BoxDecoration(
                        color: (p.isLocked ? const Color(0xFF94A3B8) : const Color(0xFF10B981)).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        p.isLocked ? Icons.lock_rounded : Icons.check_circle_outline_rounded,
                        color: p.isLocked ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
                          const SizedBox(height: 2),
                          Text(
                            "${_sourceLabel(p.source)} · ${_methodLabel(p.method)}"
                                "${p.date != null ? ' · ${DateFormat('dd.MM.yyyy').format(p.date!)}' : ''}",
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "+${currencyFormat.format(p.amount)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              )),
          ],
        ),
      );
    });
  }
}