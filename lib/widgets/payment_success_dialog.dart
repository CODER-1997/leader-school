import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/admin_controller/admin_settings_controller.dart';
import '../../services/sms_service.dart'; // MUHIM: agar boshqa yo'lda bo'lsa, to'g'irlang
import 'printer_picker_sheet.dart';

/// MUHIM: bu fayl uchun pubspec.yaml'ga qo'shing:
///   flutter pub add print_bluetooth_thermal esc_pos_utils_plus get_storage
///   share_plus: ^7.2.0   (MUHIM: 12.x EMAS — u yangiroq Android Gradle
///                         Plugin talab qiladi va build xatosi beradi)
///   path_provider: ^2.1.0
///
/// To'lov saqlangach chiqadigan muvaffaqiyat oynasi: katta yashil check,
/// va pastda 3 ta harakat tugmasi — SMS, Chek chop etish, Telegram orqali
/// yuborish.
void showPaymentSuccessDialog({
  required String studentName,
  required double amount,
  required DateTime date,
  required String method,
  String? parentPhone,
  String? forMonthLabel,
}) {
  Get.dialog(
    _PaymentSuccessContent(
      studentName: studentName,
      amount: amount,
      date: date,
      method: method,
      parentPhone: parentPhone,
      forMonthLabel: forMonthLabel,
    ),
    barrierDismissible: true,
  );
}

class _PaymentSuccessContent extends StatefulWidget {
  final String studentName;
  final double amount;
  final DateTime date;
  final String method;
  final String? parentPhone;
  final String? forMonthLabel;

  const _PaymentSuccessContent({
    required this.studentName,
    required this.amount,
    required this.date,
    required this.method,
    this.parentPhone,
    this.forMonthLabel,
  });

  @override
  State<_PaymentSuccessContent> createState() => _PaymentSuccessContentState();
}

class _PaymentSuccessContentState extends State<_PaymentSuccessContent> with SingleTickerProviderStateMixin {
  final GlobalKey _receiptKey = GlobalKey();
  late final AnimationController _checkController;

  bool _isSendingSms = false;
  bool _isPrinting = false;
  bool _isSharing = false;

  // TEST REJIMI: xuddi davomat SMS'idagi kabi, hozircha BARCHA to'lov
  // SMS'lari shu raqamga yuboriladi. Test tugagach, _handleSendSms()
  // ichida shu qatorni o'chirib, widget.parentPhone'ni ishlating.

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..forward();
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'card':
        return "Karta";
      case 'bank_transfer':
        return "O'tkazma";
      default:
        return "Naqt";
    }
  }

  String _formatAmount(double amount) => NumberFormat("#,###", "uz").format(amount);

  Widget _fiscalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Color(0xFF94A3B8))),
        Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
      ],
    );
  }

  Widget _fiscalDivider() {
    return CustomPaint(size: const Size(double.infinity, 1), painter: _DashedLinePainter());
  }

  // --- SMS ---
  Future<void> _handleSendSms() async {
    // TEST REJIMI: haqiqiy parentPhone tekshiruvi vaqtincha o'chirilgan —
    // test tugagach, pastdagi izohlangan bloklarni qayta yoqing.
    // if (widget.parentPhone == null || widget.parentPhone!.trim().isEmpty) {
    //   Get.snackbar("Diqqat", "Ota-ona telefon raqami kiritilmagan", backgroundColor: Colors.orange, colorText: Colors.white);
    //   return;
    // }

    setState(() => _isSendingSms = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('sms_templates').get();
      final template = doc.data()?['paymentReceived'] ?? AdminSettingsController.defaultPaymentReceivedTemplate;

      final message = template
          .toString()
          .replaceAll('{ism}', widget.studentName)
          .replaceAll('{miqdor}', _formatAmount(widget.amount))
          .replaceAll('{sana}', DateFormat('dd.MM.yyyy').format(widget.date));

      // TEST REJIMI: haqiqiy widget.parentPhone o'rniga test raqamiga
      // yuboriladi. Testdan keyin `widget.parentPhone!`ga almashtiring.
      await SMSService().sendSMS(widget.parentPhone!, message);
      // await SMSService().sendSMS(widget.parentPhone!, message);

      Get.snackbar("Yuborildi", "SMS ota-onaga yuborildi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xatolik", "SMS yuborilmadi: $e", backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isSendingSms = false);
    }
  }

  // --- CHEK CHOP ETISH ---
  // MUHIM: Bluetooth ESC/POS chop etish hali sozlanmoqda (debug bosqichida),
  // shuning uchun vaqtincha "Tez kunda" ko'rsatiladi. Haqiqiy chaqiruv
  // (printReceiptViaBluetooth) pastda IZOHLANGAN holda saqlangan — sozlash
  // tugagach, shunchaki izohni olib tashlang va _showComingSoon() qatorini
  // o'chiring.
  Future<void> _handlePrint() async {
    _showComingSoon();
    return;

    // ignore: dead_code
    setState(() => _isPrinting = true);
    try {
      final success = await printReceiptViaBluetooth(
        context,
        studentName: widget.studentName,
        amount: widget.amount,
        date: widget.date,
        method: widget.method,
      );
      if (success) {
        Get.snackbar("Chop etildi", "Chek printerga yuborildi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar("Xatolik", "Chop etishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _showComingSoon() {
    Get.snackbar(
      "Tez kunda",
      "Chek chop etish funksiyasi hozircha sozlanmoqda",
      backgroundColor: const Color(0xFF64748B),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
    );
  }

  // --- TELEGRAM (rasm sifatida ulashish) ---
  Future<void> _handleShareTelegram() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Chek rasmini olib bo'lmadi");

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Rasmni saqlab bo'lmadi");

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/chek_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // MUHIM: share_plus 12.x YANGI (SharePlus.instance.share) API talab
      // qiladi, lekin u Android Gradle Plugin >=8.12.1 talab qiladi — bu
      // ko'pchilik mavjud loyihalarda yo'q va butun Android qurilish
      // tizimini yangilashni talab qiladi (xavfli, keraksiz). Shuning
      // uchun share_plus ESKI, BARQAROR versiyaga (pubspec.yaml'da
      // `share_plus: ^7.2.0`) tushirilgan, va shu versiyaning ESKI,
      // barqaror API'si ishlatilmoqda.
      await Share.shareXFiles([XFile(file.path)], text: "To'lov cheki — ${widget.studentName}");
    } catch (e) {
      Get.snackbar("Xatolik", "Ulashishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        // MUHIM: chek ko'p qatorli bo'lib qolgani sababli (Kassir, Oy
        // uchun, shtrix-kod va h.k.), butun Column balandligi ba'zi
        // kichik ekranlarda ekrandan oshib, RenderFlex overflow xatosini
        // berardi. Endi balandlik ekranning 90%i bilan cheklanadi va
        // ichkarisi SingleChildScrollView orqali o'zi scroll bo'ladi.
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, 12))],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- ANIMATSIYALI CHECK BELGISI ---
                ScaleTransition(
                  scale: CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 42),
                  ),
                ),
                const SizedBox(height: 18),
                const Text("To'landi!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 20),

                // --- FISKAL CHEK KO'RINISHI (haqiqiy kassa chekiga o'xshash) ---
                RepaintBoundary(
                  key: _receiptKey,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: Colors.white, // rasmga olinganda shaffof bo'lmasligi uchun
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipPath(
                          clipper: _ReceiptZigzagClipper(),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6))],
                            ),
                            child: Stack(
                              children: [
                                // --- FON XAVFSIZLIK NAQSHI (guilloche uslubida, juda xira) ---
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0.035,
                                    child: CustomPaint(painter: _GuillochePatternPainter()),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.school_rounded, color: Color(0xFF0F172A), size: 22),
                                      const SizedBox(height: 6),
                                      const Text(
                                        "LEADER SCHOOL",
                                        style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2, color: Color(0xFF0F172A)),
                                      ),
                                      const Text(
                                        "TO'LOV CHEKI",
                                        style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, letterSpacing: 3, color: Color(0xFF94A3B8)),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(width: 32, height: 2, color: const Color(0xFF10B981)),
                                      const SizedBox(height: 14),
                                      _fiscalDivider(),
                                      const SizedBox(height: 10),

                                      _fiscalRow("O'quvchi", widget.studentName),
                                      const SizedBox(height: 5),
                                      _fiscalRow("Sana", DateFormat('dd.MM.yyyy HH:mm').format(widget.date)),
                                      const SizedBox(height: 5),
                                      _fiscalRow("To'lov turi", _methodLabel(widget.method)),
                                      const SizedBox(height: 5),
                                      if (widget.forMonthLabel != null) ...[
                                        _fiscalRow("Oy uchun", widget.forMonthLabel!),
                                        const SizedBox(height: 5),
                                      ],
                                      _fiscalRow("Kassir", "Admin"),
                                      const SizedBox(height: 5),
                                      _fiscalRow("Chek №", "${DateTime.now().millisecondsSinceEpoch}".substring(6)),

                                      const SizedBox(height: 12),
                                      _fiscalDivider(),
                                      const SizedBox(height: 12),

                                      const Row(
                                        children: [
                                          Expanded(child: Text("1x O'quv to'lovi", style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF334155)))),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _fiscalDivider(),
                                      const SizedBox(height: 12),

                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text("JAMI", style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A), letterSpacing: 1)),
                                          Text(
                                            "${_formatAmount(widget.amount)} so'm",
                                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 18),
                                      SizedBox(
                                        height: 34,
                                        child: CustomPaint(size: const Size(double.infinity, 34), painter: _BarcodePainter()),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "${DateTime.now().millisecondsSinceEpoch}",
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Color(0xFFCBD5E1), letterSpacing: 1),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        "Xarid uchun rahmat!",
                                        style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                       

                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // --- 3 TA HARAKAT TUGMASI ---
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.sms_rounded,
                        label: "SMS",
                        color: const Color(0xFF3B82F6),
                        isLoading: _isSendingSms,
                        onTap: _handleSendSms,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.print_rounded,
                        label: "Chek",
                        color: const Color(0xFF8B5CF6),
                        isLoading: _isPrinting,
                        onTap: _handlePrint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.telegram_rounded,
                        label: "Telegram",
                        color: const Color(0xFF10B981),
                        isLoading: _isSharing,
                        onTap: _handleShareTelegram,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Get.back(),
                    child: const Text("Yopish", style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            isLoading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: color))
                : Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Chek pastida "yirtilgan qog'oz" hissi beruvchi uzuq-uzuq chiziq.
class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Haqiqiy dumaloq muhrga o'xshash "TO'LANDI" shtampi — ikki qatorli
/// halqa, o'rtada qalin matn, atrofida kichik yulduzchalar (Markaziy
/// Osiyoda keng tarqalgan yashil rangli to'lov muhrlariga o'xshash).

/// Rasmiy hujjatlarda uchraydigan "guilloche" xavfsizlik naqshini
/// taqlid qiluvchi, juda xira (deyarli sezilmaydigan) fon chizig'i.
class _GuillochePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    for (double y = -size.width; y < size.height + size.width; y += 10) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + size.width), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Kassa chekining pastki qismidagi zigzag (yirtilgan) chetini chizadi.
class _ReceiptZigzagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const double zigWidth = 12;
    const double zigHeight = 6;
    final path = Path()..lineTo(0, 0);

    path.lineTo(0, size.height - zigHeight);
    double x = 0;
    bool up = true;
    while (x < size.width) {
      path.lineTo(x + zigWidth / 2, up ? size.height : size.height - zigHeight);
      up = !up;
      x += zigWidth / 2;
    }
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Fiskal chekdagi shtrix-kodni taqlid qiluvchi dekorativ chizmachi
/// (funksional emas, faqat vizual haqiqiylik uchun).
class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1E293B);
    final random = DateTime.now().millisecondsSinceEpoch;
    double x = 0;
    int i = 0;
    while (x < size.width) {
      final barWidth = ((random ~/ (i + 1)) % 3 == 0) ? 3.0 : 1.5;
      canvas.drawRect(Rect.fromLTWH(x, 0, barWidth, size.height), paint);
      x += barWidth + 2.5;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}