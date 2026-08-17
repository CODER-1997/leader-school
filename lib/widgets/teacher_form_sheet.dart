import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../controllers/admin_controller/admin_teacher_controller.dart';

/// Yangi o'qituvchi/admin qo'shish HAM tahrirlash uchun ishlatiladigan
/// TO'LIQ EKRAN (bottom sheet EMAS).
///
/// SABAB: bottom sheet + klaviatura + o'zgaruvchan balandlikdagi forma
/// (rol almashtirilganda qo'shimcha maydonlar chiqishi) birgalikda bir
/// necha marta hal qilib bo'lmagan vizual muammolarga sabab bo'ldi.
/// Oddiy Scaffold sahifasi esa klaviaturani MUAMMOSIZ, avtomatik
/// boshqaradi (resizeToAvoidBottomInset — Flutter'ning standart, hech
/// qanday qo'shimcha sozlashsiz ishlaydigan xususiyati) — shuning uchun
/// bu yerda hech qanday maxsus balandlik/klaviatura kodi kerak emas.
class TeacherFormScreen extends StatefulWidget {
  final AdminTeacherController controller;
  final TeacherSummary? existing;

  const TeacherFormScreen({super.key, required this.controller, this.existing});

  @override
  State<TeacherFormScreen> createState() => _TeacherFormScreenState();
}

class _TeacherFormScreenState extends State<TeacherFormScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  final _phoneFormatter = MaskTextInputFormatter(
    mask: '+998 (##) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  late String _role;
  late bool _canViewPayments;
  late bool _canEditPayments;
  late bool _canSendSms;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _firstNameController = TextEditingController(text: e?.firstName ?? '');
    _lastNameController = TextEditingController(text: e?.lastName ?? '');
    _phoneController = TextEditingController(text: e?.phone ?? '');
    _role = e?.role ?? TeacherRole.teacher;
    _canViewPayments = e?.permissions['viewPayments'] ?? false;
    _canEditPayments = e?.permissions['editPayments'] ?? false;
    _canSendSms = e?.permissions['sendSms'] ?? false;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      Get.snackbar("Diqqat", "Ism va familiyani kiriting", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    if (!_isEdit && phone.replaceAll(RegExp(r'\D'), '').length < 9) {
      Get.snackbar("Diqqat", "Telefon raqamini to'liq kiriting", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    // Admin ham teacher kabi FAQAT switch orqali belgilangan aniq
    // ruxsatlarga ega bo'ladi — rolga qarab avtomatik true berilmaydi.
    final permissions = {
      'viewPayments': _canViewPayments,
      'editPayments': _canEditPayments,
      'sendSms': _canSendSms,
    };

    setState(() => _isSaving = true);

    bool success;
    if (_isEdit) {
      success = await widget.controller.updateTeacher(
        id: widget.existing!.id,
        firstName: firstName,
        lastName: lastName,
        role: _role,
        permissions: permissions,
      );
    } else {
      success = await widget.controller.addTeacher(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        role: _role,
        permissions: permissions,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          _isEdit ? "Ma'lumotni tahrirlash" : "Yangi o'qituvchi / admin",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 17),
        ),
      ),
      // resizeToAvoidBottomInset default TRUE — klaviatura ochilganda
      // butun Column (shu jumladan pastdagi tugma) avtomatik yuqoriga
      // suriladi, hech narsa qo'shimcha sozlash shart emas.
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameController,
                            decoration: _decoration("Ismi"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lastNameController,
                            decoration: _decoration("Familiyasi"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _phoneController,
                      enabled: !_isEdit, // Telefon = unikal ID, tahrirlashda o'zgartirilmaydi
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_phoneFormatter],
                      decoration: _decoration("Telefon raqami").copyWith(
                        hintText: "+998 (90) 123-45-67",
                        suffixIcon: _isEdit ? const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF94A3B8)) : null,
                      ),
                    ),
                    if (_isEdit)
                      const Padding(
                        padding: EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          "Telefon raqami unikal ID sifatida ishlatiladi, shuning uchun o'zgartirilmaydi",
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ),

                    const SizedBox(height: 24),
                    const Text("Rol", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleChip(
                            label: "O'qituvchi",
                            icon: Icons.school_outlined,
                            selected: _role == TeacherRole.teacher,
                            onTap: () => setState(() => _role = TeacherRole.teacher),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _RoleChip(
                            label: "Admin",
                            icon: Icons.admin_panel_settings_outlined,
                            selected: _role == TeacherRole.admin,
                            onTap: () => setState(() => _role = TeacherRole.admin),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Text("Ruxsatlar", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 13)),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        _PermissionSwitch(
                          label: "To'lovlarni ko'rish",
                          value: _canViewPayments,
                          onChanged: (v) => setState(() => _canViewPayments = v),
                        ),
                        _PermissionSwitch(
                          label: "To'lovlarni tahrirlash",
                          value: _canEditPayments,
                          onChanged: (v) => setState(() => _canEditPayments = v),
                        ),
                        _PermissionSwitch(
                          label: "SMS yuborish",
                          value: _canSendSms,
                          onChanged: (v) => setState(() => _canSendSms = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
              : Text(
            _isEdit ? "Saqlash" : "Qo'shish",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

InputDecoration _decoration(String label) {
  return InputDecoration(
    labelText: label,
    // MUHIM: avval fillColor sahifa foni (Scaffold backgroundColor)
    // bilan BIR XIL rangda edi (0xFFF8FAFC ikkalasi ham) — shuning uchun
    // maydonlar fonga singib, chegarasi ko'rinmay qolgan edi. Endi oq
    // fon + ko'rinadigan enabledBorder bilan aniq kontrast beriladi.
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
  );
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10B981).withOpacity(0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: selected ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: selected ? const Color(0xFF10B981) : const Color(0xFF334155))),
          ],
        ),
      ),
    );
  }
}

class _PermissionSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionSwitch({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)))),
          Switch.adaptive(value: value, activeColor: const Color(0xFF10B981), onChanged: onChanged),
        ],
      ),
    );
  }
}