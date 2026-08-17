 import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// MUHIM: bu fayl uchun pubspec.yaml'ga qo'shing (aniq versiyani belgilamasdan
/// eng oxirgi mos versiyani olish uchun terminaldan buyruq bilan qo'shish
/// tavsiya etiladi, share_plus'da bo'lgani kabi versiya nomuvofiqligining
/// oldini olish uchun):
///
///   flutter pub add print_bluetooth_thermal esc_pos_utils_plus
///
/// ANDROID: android/app/src/main/AndroidManifest.xml'ga (agar Android 12+
/// nishonlansa) shular kerak bo'lishi mumkin:
///   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
///   <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
///
/// ESLATMA: bu paket faqat TELEFON SOZLAMALARIDA ALLAQACHON JUFTLASHTIRILGAN
/// (paired) printerlar bilan ishlaydi — o'zi yangi juftlashtirmaydi.
/// Avval telefonning Bluetooth sozlamalaridan printer bilan juftlashtiring.
class BluetoothPrinterService {
  BluetoothPrinterService._();

  static const String _savedMacKey = 'saved_printer_mac';
  static const String _savedNameKey = 'saved_printer_name';

  // MUHIM: printeringiz qog'oz kengligi. Ko'pchilik kichik chek
  // printerlar 58mm. Agar sizniki 80mm bo'lsa, shu qatorni
  // PaperSize.mm80'ga o'zgartiring.
  static   PaperSize paperSize = PaperSize.mm58;

  static Future<List<BluetoothInfo>> getPairedPrinters() =>
      PrintBluetoothThermal.pairedBluetooths;

  static String? get savedPrinterMac => GetStorage().read<String>(_savedMacKey);
  static String? get savedPrinterName => GetStorage().read<String>(_savedNameKey);

  static Future<void> savePrinter(String mac, String name) async {
    final box = GetStorage();
    await box.write(_savedMacKey, mac);
    await box.write(_savedNameKey, name);
  }

  static Future<void> forgetPrinter() async {
    final box = GetStorage();
    await box.remove(_savedMacKey);
    await box.remove(_savedNameKey);
  }

  static Future<bool> connect(String macAddress) async {
    final alreadyConnected = await PrintBluetoothThermal.connectionStatus;
    if (alreadyConnected) {
      await PrintBluetoothThermal.disconnect;
    }
    return PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  static String _methodLabel(String method) {
    switch (method) {
      case 'card':
        return "Karta";
      case 'bank_transfer':
        return "O'tkazma";
      default:
        return "Naqt";
    }
  }

  /// Ulangan printerga to'lov chekini ESC/POS formatda yuboradi.
  /// Avval connect(macAddress) chaqirilgan bo'lishi shart.
  static Future<bool> printReceipt({
    required String studentName,
    required double amount,
    required DateTime date,
    required String method,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    bytes += generator.text(
      'LEADER SCHOOL',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.text("TO'LOV CHEKI", styles: const PosStyles(align: PosAlign.center));
    bytes += generator.emptyLines(1);
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(text: "O'quvchi", width: 4, styles: const PosStyles(bold: false)),
      PosColumn(text: studentName, width: 8, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.row([
      PosColumn(text: "Sana", width: 4),
      PosColumn(text: DateFormat('dd.MM.yyyy HH:mm').format(date), width: 8, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: "Turi", width: 4),
      PosColumn(text: _methodLabel(method), width: 8, styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: "JAMI", width: 4, styles: const PosStyles(bold: true)),
      PosColumn(
        text: "${NumberFormat("#,###", "uz").format(amount)} so'm",
        width: 8,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
      ),
    ]);
    bytes += generator.hr(ch: '=');

    bytes += generator.text(
      "TO'LANDI",
      styles: const PosStyles(align: PosAlign.center, bold: true, reverse: true, height: PosTextSize.size2, width: PosTextSize.size2),
      linesAfter: 1,
    );
    bytes += generator.text("Xarid uchun rahmat!", styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return PrintBluetoothThermal.writeBytes(bytes);
  }
}