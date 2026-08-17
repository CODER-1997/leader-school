 import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/admin_controller/admin_security_controller.dart';
import '../../controllers/admin_controller/admin_settings_controller.dart';
import '../../services/access_code_service.dart';
import '../../services/get_helper.dart';

/// Sozlamalar ekrani — TABBAR YO'Q. Bitta vertikal ro'yxat, ichida bo'lim
/// sarlavhalari (SMS / Xavfsizlik) va har biri ostida accordion kartalar.
/// Foydalanuvchi hammasini bir joyda scroll qilib ko'radi, kerakli kartani
/// ochib tahrirlaydi.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  // Bir vaqtda faqat BITTA karta ochiq bo'lishi uchun umumiy kalit.
  // Har bir kartaning o'ziga xos ID'si bor (masalan 'sms_attendance',
  // 'security_code'), shu orqali qaysi biri ochiqligini bilamiz.
  String? _expandedKey;

  void _toggle(String key) {
    setState(() => _expandedKey = (_expandedKey == key) ? null : key);
  }

  @override
  Widget build(BuildContext context) {
    final smsController = putOnce(() => AdminSettingsController(), tag: 'admin_settings');
    final securityController = putOnce(() => AdminSecurityController(), tag: 'admin_security');

    return Obx(() {
      if (smsController.isLoading.value || securityController.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5));
      }

      return RefreshIndicator(
        color: const Color(0xFF10B981),
        onRefresh: securityController.refreshLogs,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const _SectionHeader(title: "SMS shablonlari", subtitle: "Ota-onalarga avtomatik yuboriladigan matnlar"),
            const SizedBox(height: 10),
            _SmsTemplateCard(
              cardKey: 'sms_attendance',
              icon: Icons.fact_check_outlined,
              iconColor: const Color(0xFF3B82F6),
              title: "Davomat haqida",
              placeholders: const ["{ism}", "{sinf}", "{sana}"],
              textController: smsController.attendanceController,
              dirty: smsController.attendanceDirty,
              isSaving: smsController.isSavingAttendance,
              onSave: smsController.saveAttendanceTemplate,
              expanded: _expandedKey == 'sms_attendance',
              onToggle: () => _toggle('sms_attendance'),
            ),
            const SizedBox(height: 10),
            _SmsTemplateCard(
              cardKey: 'sms_payment',
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFFF59E0B),
              title: "To'lov kechikkani haqida",
              placeholders: const ["{ism}", "{kechikkanKun}", "{miqdor}"],
              textController: smsController.paymentDelayController,
              dirty: smsController.paymentDelayDirty,
              isSaving: smsController.isSavingPaymentDelay,
              onSave: smsController.savePaymentDelayTemplate,
              expanded: _expandedKey == 'sms_payment',
              onToggle: () => _toggle('sms_payment'),
            ),
            const SizedBox(height: 10),
            _SmsTemplateCard(
              cardKey: 'sms_exam',
              icon: Icons.assignment_turned_in_outlined,
              iconColor: const Color(0xFF10B981),
              title: "Imtihon natijasi haqida",
              placeholders: const ["{ism}", "{imtihon}", "{ball}"],
              textController: smsController.examResultController,
              dirty: smsController.examResultDirty,
              isSaving: smsController.isSavingExamResult,
              onSave: smsController.saveExamResultTemplate,
              expanded: _expandedKey == 'sms_exam',
              onToggle: () => _toggle('sms_exam'),
            ),
            const SizedBox(height: 10),
            _SmsTemplateCard(
              cardKey: 'sms_payment_received',
              icon: Icons.receipt_long_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: "To'lov qabul qilingani haqida",
              placeholders: const ["{ism}", "{miqdor}", "{sana}"],
              textController: smsController.paymentReceivedController,
              dirty: smsController.paymentReceivedDirty,
              isSaving: smsController.isSavingPaymentReceived,
              onSave: smsController.savePaymentReceivedTemplate,
              expanded: _expandedKey == 'sms_payment_received',
              onToggle: () => _toggle('sms_payment_received'),
            ),

            const SizedBox(height: 28),
            const _SectionHeader(title: "Xavfsizlik", subtitle: "Kirish kodi, parol va kirish tarixi"),
            const SizedBox(height: 10),
            _AccessCodeCard(
              expanded: _expandedKey == 'security_code',
              onToggle: () => _toggle('security_code'),
            ),
            const SizedBox(height: 10),
            _PasswordCard(
              controller: securityController,
              expanded: _expandedKey == 'security_password',
              onToggle: () => _toggle('security_password'),
            ),

            const SizedBox(height: 24),
            const _SectionHeader(title: "Kirish tarixi", subtitle: "Admin bo'limiga so'nggi kirish urinishlari"),
            const SizedBox(height: 10),
            _LoginHistoryList(controller: securityController),
          ],
        ),
      );
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      ],
    );
  }
}

// =========================================================================
// UMUMIY ACCORDION KARTA
// =========================================================================
class _AccordionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget subtitle;
  final Widget? trailingBadge;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _AccordionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailingBadge,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: expanded ? const Color(0xFF10B981).withOpacity(0.35) : const Color(0xFFEEF2F6), width: expanded ? 1.3 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B))),
                        const SizedBox(height: 3),
                        subtitle,
                      ],
                    ),
                  ),
                  if (trailingBadge != null) ...[trailingBadge!, const SizedBox(width: 8)],
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;
  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: active ? const Color(0xFF10B981) : const Color(0xFFCBD5E1), shape: BoxShape.circle),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
  );
}

// =========================================================================
// SMS SHABLON KARTASI
// =========================================================================
class _SmsTemplateCard extends StatelessWidget {
  final String cardKey;
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> placeholders;
  final TextEditingController textController;
  final RxBool dirty;
  final RxBool isSaving;
  final Future<void> Function() onSave;
  final bool expanded;
  final VoidCallback onToggle;

  const _SmsTemplateCard({
    required this.cardKey,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.placeholders,
    required this.textController,
    required this.dirty,
    required this.isSaving,
    required this.onSave,
    required this.expanded,
    required this.onToggle,
  });

  String _preview(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return "Hali tahrirlanmagan";
    return trimmed.length > 48 ? "${trimmed.substring(0, 48)}…" : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => _AccordionCard(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: Text(
        _preview(textController.text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
      ),
      trailingBadge: dirty.value ? Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)) : null,
      expanded: expanded,
      onToggle: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: placeholders.map((p) {
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  final text = textController.text;
                  final selection = textController.selection;
                  final insertAt = selection.start >= 0 ? selection.start : text.length;
                  final newText = text.replaceRange(insertAt, insertAt, p);
                  textController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: insertAt + p.length));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Text(p, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: textController,
            maxLines: 4,
            minLines: 3,
            autofocus: true,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: dirty.value ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  elevation: 0,
                ),
                onPressed: (dirty.value && !isSaving.value) ? onSave : null,
                icon: isSaving.value
                    ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.save_rounded, size: 15, color: dirty.value ? Colors.white : const Color(0xFF94A3B8)),
                label: Text("Saqlash", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: dirty.value ? Colors.white : const Color(0xFF94A3B8))),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

// =========================================================================
// MAXSUS KOD KARTASI
// =========================================================================
class _AccessCodeCard extends StatefulWidget {
  final bool expanded;
  final VoidCallback onToggle;
  const _AccessCodeCard({required this.expanded, required this.onToggle});

  @override
  State<_AccessCodeCard> createState() => _AccessCodeCardState();
}

class _AccessCodeCardState extends State<_AccessCodeCard> {
  final _currentCodeController = TextEditingController();
  final _newCodeController = TextEditingController();
  final _confirmCodeController = TextEditingController();
  bool _hasCodeSet = false;
  bool _checking = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final has = await AccessCodeService.hasAdminCodeSet();
    if (!mounted) return;
    setState(() {
      _hasCodeSet = has;
      _checking = false;
    });
  }

  Future<void> _save() async {
    if (_newCodeController.text != _confirmCodeController.text) {
      Get.snackbar("Diqqat", "Yangi kodlar mos kelmadi", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    if (_newCodeController.text.trim().length < 4) {
      Get.snackbar("Diqqat", "Kod kamida 4 ta belgidan iborat bo'lishi kerak", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    setState(() => _saving = true);
    final ok = await AccessCodeService.setAdminCode(
      newCode: _newCodeController.text,
      currentCode: _currentCodeController.text.isEmpty ? null : _currentCodeController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _currentCodeController.clear();
      _newCodeController.clear();
      _confirmCodeController.clear();
      setState(() => _hasCodeSet = true);
      widget.onToggle();
      Get.snackbar("Saqlandi", "Maxsus kod yangilandi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } else {
      Get.snackbar("Xatolik", _hasCodeSet ? "Joriy kod noto'g'ri" : "Kodni saqlashda xato", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  void dispose() {
    _currentCodeController.dispose();
    _newCodeController.dispose();
    _confirmCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEEF2F6))),
        child: const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))),
      );
    }

    return _AccordionCard(
      icon: Icons.vpn_key_outlined,
      iconColor: const Color(0xFF8B5CF6),
      title: "Maxsus kod",
      subtitle: Row(
        children: [
          _StatusDot(active: _hasCodeSet),
          const SizedBox(width: 6),
          Text(
            _hasCodeSet ? "O'rnatilgan" : "O'rnatilmagan — standart kod ishlamoqda",
            style: TextStyle(fontSize: 11.5, color: _hasCodeSet ? const Color(0xFF94A3B8) : const Color(0xFFD97706)),
          ),
        ],
      ),
      expanded: widget.expanded,
      onToggle: widget.onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Bosh ekrandan \"admin\" huquqini beruvchi kod", style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
          if (!_hasCodeSet) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10)),
              child: const Text(
                "Hozircha vaqtinchalik standart kod (\"admin\") ishlaydi. Xavfsizlik uchun darhol o'z kodingizni o'rnating.",
                style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_hasCodeSet) ...[
            TextField(controller: _currentCodeController, obscureText: true, autofocus: true, decoration: _fieldDecoration("Joriy kod")),
            const SizedBox(height: 10),
          ],
          TextField(controller: _newCodeController, obscureText: true, autofocus: !_hasCodeSet, decoration: _fieldDecoration("Yangi kod (kamida 4 belgi)")),
          const SizedBox(height: 10),
          TextField(controller: _confirmCodeController, obscureText: true, decoration: _fieldDecoration("Yangi kodni tasdiqlang")),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)), elevation: 0),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Saqlash", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// ADMIN PANEL PAROLI KARTASI
// =========================================================================
class _PasswordCard extends StatefulWidget {
  final AdminSecurityController controller;
  final bool expanded;
  final VoidCallback onToggle;
  const _PasswordCard({required this.controller, required this.expanded, required this.onToggle});

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  Future<void> _save() async {
    if (_newController.text != _confirmController.text) {
      Get.snackbar("Diqqat", "Yangi parollar mos kelmadi", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    final ok = await widget.controller.setPassword(
      newPassword: _newController.text,
      currentPassword: _currentController.text.isEmpty ? null : _currentController.text,
    );

    if (ok) {
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      widget.onToggle();
    }
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => _AccordionCard(
      icon: Icons.lock_outline_rounded,
      iconColor: const Color(0xFFEF4444),
      title: "Admin panel paroli",
      subtitle: Row(
        children: [
          _StatusDot(active: widget.controller.hasPasswordSet.value),
          const SizedBox(width: 6),
          Text(
            widget.controller.hasPasswordSet.value ? "O'rnatilgan" : "O'rnatilmagan",
            style: TextStyle(fontSize: 11.5, color: widget.controller.hasPasswordSet.value ? const Color(0xFF94A3B8) : const Color(0xFFD97706)),
          ),
        ],
      ),
      expanded: widget.expanded,
      onToggle: widget.onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Admin bo'limiga har safar kirishda so'raladi", style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
          const SizedBox(height: 12),
          if (widget.controller.hasPasswordSet.value) ...[
            TextField(controller: _currentController, obscureText: true, autofocus: true, decoration: _fieldDecoration("Joriy parol")),
            const SizedBox(height: 10),
          ],
          TextField(controller: _newController, obscureText: true, autofocus: !widget.controller.hasPasswordSet.value, decoration: _fieldDecoration("Yangi parol (kamida 4 belgi)")),
          const SizedBox(height: 10),
          TextField(controller: _confirmController, obscureText: true, decoration: _fieldDecoration("Yangi parolni tasdiqlang")),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)), elevation: 0),
              onPressed: widget.controller.isSaving.value ? null : _save,
              child: widget.controller.isSaving.value
                  ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Saqlash", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ));
  }
}

// =========================================================================
// KIRISH TARIXI — INSON O'QIY OLADIGAN FORMATDA
// =========================================================================
class _LoginHistoryList extends StatefulWidget {
  final AdminSecurityController controller;
  const _LoginHistoryList({required this.controller});

  @override
  State<_LoginHistoryList> createState() => _LoginHistoryListState();
}

class _LoginHistoryListState extends State<_LoginHistoryList> {
  bool _showAll = false;

  String _platformLabel(String platform) {
    switch (platform) {
      case 'android':
        return "Android qurilma";
      case 'ios':
        return "iPhone / iPad";
      case 'web':
        return "Veb-brauzer";
      default:
        return "Noma'lum qurilma";
    }
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'android':
        return Icons.android_rounded;
      case 'ios':
        return Icons.apple_rounded;
      case 'web':
        return Icons.language_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  /// Vaqtni "5 daqiqa oldin", "3 soat oldin", "Kecha, 14:32",
  /// "12-avgust, 09:15" kabi inson o'qiy oladigan shaklga o'giradi —
  /// xom timestamp ("2026-08-11 14:32:07.000") o'rniga.
  String _humanTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return "Hozirgina";
    if (diff.inMinutes < 60) return "${diff.inMinutes} daqiqa oldin";
    if (diff.inHours < 24 && dt.day == now.day) return "${diff.inHours} soat oldin";

    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return "Kecha, ${DateFormat('HH:mm').format(dt)}";
    }

    if (dt.year == now.year) {
      // MUHIM: DateFormat('...', 'uz') lokal ma'lumotlarni talab qiladi
      // (initializeDateFormatting() chaqirilishi kerak) — agar ilovada
      // hali sozlanmagan bo'lsa xato beradi. Shu sababli, ilovaning
      // qolgan qismida ishlatilgan xavfsiz, raqamli formatga qaytamiz.
      return DateFormat('dd.MM, HH:mm').format(dt);
    }

    return DateFormat('dd.MM.yyyy, HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (widget.controller.isLoadingLogs.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2)),
        );
      }

      final logs = widget.controller.loginLogs;

      if (logs.isEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEEF2F6))),
          child: const Center(
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 34, color: Color(0xFF94A3B8)),
                SizedBox(height: 10),
                Text("Hali kirish urinishlari yo'q", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ],
            ),
          ),
        );
      }

      final visible = _showAll ? logs : logs.take(5).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...visible.map((log) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEEF2F6))),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (log.success ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(_platformIcon(log.platform), size: 18, color: log.success ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_platformLabel(log.platform), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF1E293B))),
                      const SizedBox(height: 2),
                      Text(
                        log.timestamp != null ? _humanTime(log.timestamp!) : "Vaqt noma'lum",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: log.success ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    log.success ? "Muvaffaqiyatli" : "Rad etildi",
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: log.success ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          )),
          if (logs.length > 5)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll ? "Kamroq ko'rsatish" : "Barchasini ko'rish (${logs.length})",
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      );
    });
  }
}