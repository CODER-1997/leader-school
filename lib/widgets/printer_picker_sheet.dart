import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../services/bluetooth_service.dart';
/// Bluetooth printerni tanlash/chop etish oqimi:
/// 1. Agar avval saqlangan printer bo'lsa — to'g'ridan-to'g'ri ulanib
///    chop etishga urinadi (foydalanuvchi hech narsa bosishi shart emas).
/// 2. Muvaffaqiyatsiz bo'lsa yoki saqlangan printer yo'q bo'lsa —
///    juftlashtirilgan qurilmalar ro'yxatini ko'rsatadi, tanlangani
///    saqlanadi (keyingi safar avtomatik ishlatiladi).
Future<bool> printReceiptViaBluetooth(
    BuildContext context, {
      required String studentName,
      required double amount,
      required DateTime date,
      required String method,
    }) async {
  final savedMac = BluetoothPrinterService.savedPrinterMac;

  if (savedMac != null) {
    final connected = await BluetoothPrinterService.connect(savedMac);
    if (connected) {
      final printed = await BluetoothPrinterService.printReceipt(
        studentName: studentName,
        amount: amount,
        date: date,
        method: method,
      );
      if (printed) return true;
    }
    // Ulanish/chop etish muvaffaqiyatsiz — qurilma o'chirilgan yoki
    // uzoqda bo'lishi mumkin. Qayta tanlash oynasini ochamiz.
  }

  final selected = await _showDevicePicker(context);
  if (selected == null) return false;

  final connected = await BluetoothPrinterService.connect(selected.macAdress);
  if (!connected) {
    Get.snackbar("Xatolik", "Printerga ulanib bo'lmadi", backgroundColor: Colors.red, colorText: Colors.white);
    return false;
  }

  await BluetoothPrinterService.savePrinter(selected.macAdress, selected.name);

  return BluetoothPrinterService.printReceipt(
    studentName: studentName,
    amount: amount,
    date: date,
    method: method,
  );
}

Future<BluetoothInfo?> _showDevicePicker(BuildContext context) async {
  final devices = await BluetoothPrinterService.getPairedPrinters();

  if (devices.isEmpty) {
    Get.snackbar(
      "Printer topilmadi",
      "Avval telefon Bluetooth sozlamalaridan printer bilan juftlashtiring",
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
    return null;
  }

  return Get.bottomSheet<BluetoothInfo>(
    Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.print_rounded, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text("Printerni tanlang", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)))),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Faqat telefonda ALLAQACHON juftlashtirilgan qurilmalar ko'rinadi",
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          ...devices.map((d) => InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Get.back(result: d),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_rounded, size: 18, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
                        Text(d.macAdress, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                       ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                ],
              ),
            ),
          )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(onPressed: () => Get.back(result: null), child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF94A3B8)))),
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}