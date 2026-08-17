import 'package:flutter/material.dart';

import '../../views/adminstration/admin_main_view.dart';
 import 'admin_security_controller.dart';

/// Admin panelga kirishdan OLDIN turadigan qatlam.
///
/// ISHLATISH: ilovangizda "Admin" tugmasi/menyusi qayerda AdminMainView()ni
/// ochsa, o'sha joyda AdminMainView() o'rniga AdminAuthGate() ishlating:
///
///   Get.to(() => const AdminAuthGate());   // AdminMainView() EMAS
///
/// Agar Firestore'da hali parol o'rnatilmagan bo'lsa — to'g'ridan-to'g'ri
/// kirish beriladi (birinchi marta admin bo'limini sozlash uchun). Parol
/// o'rnatilgach, HAR safar admin bo'limi ochilganda shu parol so'raladi.
class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({super.key});

  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  bool _checking = true;
  bool _authenticated = false;

  final TextEditingController _pinController = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkPasswordRequirement();
  }

  Future<void> _checkPasswordRequirement() async {
    final required = await AdminSecurityController.isPasswordRequired();
    if (!mounted) return;
    setState(() {
      _authenticated = !required; // parol o'rnatilmagan bo'lsa — ochiq
      _checking = false;
    });
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty || _verifying) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    final ok = await AdminSecurityController.verifyAndLog(pin);

    if (!mounted) return;
    setState(() => _verifying = false);

    if (ok) {
      setState(() => _authenticated = true);
    } else {
      setState(() => _error = "Parol noto'g'ri");
      _pinController.clear();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5)),
      );
    }

    if (_authenticated) {
      return const AdminMainView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, size: 40, color: Color(0xFF10B981)),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Admin panelga kirish",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Davom etish uchun admin parolini kiriting",
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.visiblePassword,
                  style: const TextStyle(fontSize: 16, letterSpacing: 2),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: "Parol",
                    errorText: _error,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _verifying ? null : _submit,
                    child: _verifying
                        ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text("Kirish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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