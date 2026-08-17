import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/school_student_profil/student_payment_controller.dart';
 import 'payment_success_dialog.dart';

/// To'lov qo'shish HAM tahrirlash uchun bitta oyna.
/// [existingPayment] berilsa -> tahrirlash rejimi (muvaffaqiyat oynasi
/// chiqmaydi, chunki bu qayta to'lov emas, faqat tuzatish).
void showAddPaymentDialog(
    BuildContext context,
    StudentPaymentController controller,
    String studentName, {
      String? parentPhone,
      Map<String, dynamic>? existingPayment,
    }) {
  final bool isEdit = existingPayment != null;

  final amountController = TextEditingController(
    text: isEdit ? (existingPayment['amount'] as double).toInt().toString() : '',
  );
  DateTime selectedDate = isEdit
      ? DateTime.fromMillisecondsSinceEpoch(existingPayment['dateMs'] ?? DateTime.now().millisecondsSinceEpoch)
      : DateTime.now();
  String method = isEdit ? (existingPayment['method'] ?? 'cash') : 'cash';

  Get.dialog(
    StatefulBuilder(
      builder: (context, setState) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(isEdit ? Icons.edit_rounded : Icons.payments_rounded, color: const Color(0xFF10B981), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(isEdit ? "To'lovni tahrirlash" : "To'lov qo'shish",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    const Text("Miqdori (so'm)", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: "500 000",
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                      ),
                    ),

                    const SizedBox(height: 18),
                    const Text("Sana", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 13)),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Text(DateFormat('dd.MM.yyyy').format(selectedDate), style: const TextStyle(fontSize: 14.5, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    const Text("To'lov turi", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _MethodChip(label: "Naqt", icon: Icons.payments_outlined, selected: method == 'cash', onTap: () => setState(() => method = 'cash'))),
                        const SizedBox(width: 8),
                        Expanded(child: _MethodChip(label: "Karta", icon: Icons.credit_card_rounded, selected: method == 'card', onTap: () => setState(() => method = 'card'))),
                        const SizedBox(width: 8),
                        Expanded(child: _MethodChip(label: "O'tkazma", icon: Icons.account_balance_rounded, selected: method == 'bank_transfer', onTap: () => setState(() => method = 'bank_transfer'))),
                      ],
                    ),

                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE2E8F0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                              onPressed: () => Get.back(),
                              child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: Obx(() => ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                              onPressed: controller.isSaving.value ? null : () async {
                                final amount = double.tryParse(amountController.text) ?? 0;
                                if (amount <= 0) {
                                  Get.snackbar("Diqqat", "To'g'ri miqdor kiriting", backgroundColor: Colors.orange, colorText: Colors.white);
                                  return;
                                }

                                if (isEdit) {
                                  final ok = await controller.editPayment(
                                    paymentId: existingPayment['id'],
                                    newAmount: amount,
                                    newDate: selectedDate,
                                    newMethod: method,
                                  );
                                  if (ok) Get.back();
                                } else {
                                  final saved = await controller.addPayment(
                                    amount: amount,
                                    date: selectedDate,
                                    method: method,
                                    studentName: studentName,
                                  );
                                  if (saved != null) {
                                    Get.back();
                                    showPaymentSuccessDialog(
                                      studentName: studentName,
                                      amount: amount,
                                      date: selectedDate,
                                      method: method,
                                      parentPhone: parentPhone,
                                    );
                                  }
                                }
                              },
                              child: controller.isSaving.value
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                                  : Text(isEdit ? "Saqlash" : "Saqlash", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            )),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10B981).withOpacity(0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: selected ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: selected ? const Color(0xFF10B981) : const Color(0xFF334155))),
          ],
        ),
      ),
    );
  }
}