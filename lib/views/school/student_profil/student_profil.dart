import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../controllers/school_student_profil/school_student.dart';
import '../../../controllers/school_student_profil/student_payment_controller.dart';
import '../../../services/get_helper.dart';
import '../../../services/student_photo_service.dart';
import '../../../widgets/add_payment_dialog.dart';
import '../../../widgets/payment_success_dialog.dart';


class StudentProfileView extends StatefulWidget {
  final String studentId;
  final String subjectId;
  final String studentName;

  const StudentProfileView({
    super.key,
    required this.studentId,
    required this.subjectId,
    required this.studentName,
  });

  @override
  State<StudentProfileView> createState() => _StudentProfileViewState();
}

class _StudentProfileViewState extends State<StudentProfileView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  late final StudentProfileController _controller;
  late final StudentPaymentController _paymentController; // YANGI

  // YANGI: o'quvchi rasmi — Hive keshidan (0 Read, agar avval yuklangan bo'lsa).
  String? _photoUrl;
  bool _photoLoading = true;
  bool _photoUploading = false;
  bool _isRefreshing = false; // YANGI: AppBar'dagi umumiy "Yangilash" holati

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    // MUHIM TUZATISH: avval Get.put() build() ICHIDA chaqirilardi — bu
    // StatefulWidget bo'lgani uchun har safar setState() chaqirilganda
    // (masalan kalendarda kun bosilganda) build() qayta ishlaydi, demak
    // HAR SAFAR yangi controller yaratilib, eskisi hech qachon
    // tozalanmasdi (klassik orphan-controller muammosi). Endi initState'da
    // BIR MARTA, putOnce() bilan yaratiladi.
    _controller = putOnce(
          () => StudentProfileController(studentId: widget.studentId, subjectId: widget.subjectId),
      tag: widget.studentId,
    );
    _paymentController = putOnce(
          () => StudentPaymentController(studentId: widget.studentId),
      tag: widget.studentId,
    );

    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final url = await StudentPhotoService.getPhotoUrl(widget.studentId);
    if (!mounted) return;
    setState(() {
      _photoUrl = url;
      _photoLoading = false;
    });
  }

  // YANGI: AppBar'dagi "Yangilash" tugmasi — endi UCHALASINI HAM
  // (rasm, to'lovlar, VA shaxsiy ma'lumotlar/davomat) birga yangilaydi.
  Future<void> _refreshAll() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final results = await Future.wait([
        StudentPhotoService.refreshPhotoUrl(widget.studentId),
        _paymentController.refresh().then((_) => null),
        _controller.refresh().then((_) => null),
      ]);
      if (!mounted) return;
      setState(() => _photoUrl = results[0] as String?);
      Get.snackbar("Yangilandi", "Ma'lumotlar serverdan qayta yuklandi",
          backgroundColor: const Color(0xFF10B981), colorText: Colors.white, snackPosition: SnackPosition.TOP);
    } catch (e) {
      Get.snackbar("Xatolik", "Yangilashda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _photoUploading = true);
    try {
      final url = await StudentPhotoService.pickAndUploadPhoto(widget.studentId, source: source);
      if (url != null && mounted) {
        setState(() => _photoUrl = url);
        Get.snackbar("Saqlandi", "Rasm yangilandi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar("Xatolik", "Rasm yuklashda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  // YANGI: rasmni to'liq ekranda, pinch-to-zoom bilan ko'rsatadi.
  // Hero animatsiyasi orqali kichik doiradan silliq kattalashadi.
  void _openFullscreenPhoto() {
    if (_photoUrl == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _FullscreenPhotoView(
              photoUrl: _photoUrl!,
              heroTag: 'student_photo_${widget.studentId}',
            ),
          );
        },
      ),
    );
  }

  void _showPhotoSourceSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text("O'quvchi rasmi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF3B82F6)),
              ),
              title: const Text("Kameradan olish"),
              onTap: () {
                Get.back();
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
              ),
              title: const Text("Galereyadan tanlash"),
              onTap: () {
                Get.back();
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  void dispose() {
    // MUHIM: avval bu ekrandan chiqilganda HECH QANDAY controller
    // tozalanmasdi. Endi ikkalasi ham xotiradan o'chiriladi.
    Get.delete<StudentProfileController>(tag: widget.studentId);
    Get.delete<StudentPaymentController>(tag: widget.studentId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var phoneFormatter = MaskTextInputFormatter(
      mask: '+998 (##) ###-##-##',
      filter: { "#": RegExp(r'[0-9]') },
      type: MaskAutoCompletionType.lazy,
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          title: Text(widget.studentName, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18)),
          actions: [
            // YANGI: umumiy "Yangilash" — rasm va to'lovlarni keshni
            // chetlab, serverdan qayta yuklaydi.
            IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF10B981)),
              )
                  : const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
              onPressed: _isRefreshing ? null : _refreshAll,
              tooltip: "Yangilash",
            ),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF10B981),
            unselectedLabelColor: Color(0xFF64748B),
            indicatorColor: Color(0xFF10B981),
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Ma'lumotlar"),
              Tab(text: "Davomat"),
              Tab(text: "To'lovlar"),
            ],
          ),
        ),
        body: Obx(() {
          if (_controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            children: [
              // 1. MA'LUMOTLAR — YANGI: rasm + pull-to-refresh qo'shildi
              RefreshIndicator(
                color: const Color(0xFF10B981),
                onRefresh: _refreshAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- O'QUVCHI RASMI ---
                      Center(
                        child: Stack(
                          children: [
                            // YANGI: rasmning o'ziga bosilsa — to'liq ekranda
                            // kattalashtirib ko'rsatiladi (rasm bo'lmasa —
                            // tanlash oynasi ochiladi).
                            GestureDetector(
                              onTap: _photoUrl != null
                                  ? _openFullscreenPhoto
                                  : (_photoUploading ? null : _showPhotoSourceSheet),
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF10B981), width: 2.5),
                                  color: const Color(0xFFF1F5F9),
                                ),
                                child: ClipOval(
                                  child: (_photoLoading || _photoUploading)
                                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                                      : (_photoUrl != null
                                      ? Hero(
                                    tag: 'student_photo_${widget.studentId}',
                                    child: Image.network(
                                      _photoUrl!,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)));
                                      },
                                      errorBuilder: (context, error, stack) => const Icon(Icons.person_rounded, size: 44, color: Color(0xFF94A3B8)),
                                    ),
                                  )
                                      : const Icon(Icons.person_rounded, size: 44, color: Color(0xFF94A3B8))),
                                ),
                              ),
                            ),
                            // YANGI: o'zgartirish tugmasi endi ALOHIDA —
                            // rasmni kattalashtirish bilan aralashmaydi.
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _photoUploading ? null : _showPhotoSourceSheet,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          "Rasmni o'zgartirish uchun bosing",
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text("Shaxsiy ma'lumotlarni tahrirlash", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _controller.firstNameController, decoration: _inputDecoration("Ismi"))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: _controller.lastNameController, decoration: _inputDecoration("Familiyasi"))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(controller: _controller.phoneController, keyboardType: TextInputType.phone, inputFormatters: [phoneFormatter], decoration: _inputDecoration("O'quvchi telefoni")),
                      const SizedBox(height: 16),
                      TextField(controller: _controller.parentPhoneController, keyboardType: TextInputType.phone, inputFormatters: [phoneFormatter], decoration: _inputDecoration("Ota-ona telefoni")),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Imtiyozli (To'lovdan ozod)", style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF0F172A), fontSize: 14)),
                            Switch.adaptive(
                              value: _controller.isPrivileged.value,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) => _controller.isPrivileged.value = val,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                          onPressed: () => _controller.updateStudentProfile(),
                          child: const Text("O'zgarishlarni saqlash", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. DAVOMAT — o'zgarishsiz
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book_rounded, color: Color(0xFF059669), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Fan: ${_controller.subjectName.value.isNotEmpty ? _controller.subjectName.value : 'Yuklanmoqda...'}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2023, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onFormatChanged: (format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                          calendarStyle: const CalendarStyle(
                            todayDecoration: BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle),
                            selectedDecoration: BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                            defaultTextStyle: TextStyle(color: Color(0xFF1E293B)),
                            weekendTextStyle: TextStyle(color: Color(0xFF64748B)),
                          ),
                          eventLoader: (day) {
                            String dateKey = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
                            if (_controller.attendanceHistory.containsKey(dateKey)) {
                              return [_controller.attendanceHistory[dateKey]!];
                            }
                            return [];
                          },
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, events) {
                              if (events.isNotEmpty) {
                                bool isPresent = events.first as bool;
                                return Container(
                                  margin: const EdgeInsets.all(4),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isPresent ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text('${day.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                );
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. TO'LOVLAR — YANGI, TO'LIQ ISHLAYDIGAN BO'LIM
              _PaymentsTab(
                paymentController: _paymentController,
                studentName: widget.studentName,
                parentPhone: _controller.parentPhoneController.text,
              ),
            ],
          );
        }),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
    );
  }
}

// =========================================================================
// TO'LOVLAR TABI — mustaqil widget. Tugma pastda QOTIRILGAN (Column +
// Expanded(list) + fixed footer), ro'yxat esa tahrirlash/o'chirish/
// qulflash bilan.
// =========================================================================
class _PaymentsTab extends StatelessWidget {
  final StudentPaymentController paymentController;
  final String studentName;
  final String parentPhone;

  const _PaymentsTab({
    required this.paymentController,
    required this.studentName,
    required this.parentPhone,
  });

  void _confirmDelete(BuildContext context, Map<String, dynamic> payment) {
    final currencyFormat = NumberFormat("#,###", "uz");
    Get.bottomSheet(
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Text("To'lovni o'chirish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "${currencyFormat.format(payment['amount'])} so'm miqdoridagi to'lovni o'chirmoqchimisiz? Bu amalni qaytarib bo'lmaydi.",
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFCBD5E1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () => Get.back(),
                      child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                      onPressed: () async {
                        Get.back();
                        await paymentController.deletePayment(payment['id']);
                      },
                      child: const Text("O'chirish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat("#,###", "uz");

    return Column(
      children: [
        Expanded(
          child: Obx(() {
            if (paymentController.isLoading.value) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5));
            }

            final payments = paymentController.payments;

            return RefreshIndicator(
              color: const Color(0xFF10B981),
              onRefresh: paymentController.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  // --- JORIY OY XULOSASI ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Shu oy to'langan", style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                        const SizedBox(height: 6),
                        Text("${currencyFormat.format(paymentController.totalPaidThisMonth)} so'm",
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        if (paymentController.hasSchoolPaymentThisMonth) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: const [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text("Bu oy uchun maktab to'lovi qilingan", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text("To'lovlar tarixi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),

                  if (payments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text("Hali to'lovlar yo'q", style: TextStyle(color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                    )
                  else
                    ...payments.map((p) {
                      final method = p['method'] as String;
                      final methodLabel = method == 'card' ? "Karta" : (method == 'bank_transfer' ? "O'tkazma" : "Naqt");
                      final date = DateTime.fromMillisecondsSinceEpoch(p['dateMs'] ?? 0);
                      final bool isLocked = p['isLocked'] == true;

                      final forMonthKey = p['forMonth'] as String? ?? '';
                      String? forMonthLabel;
                      if (forMonthKey.contains('-')) {
                        final parts = forMonthKey.split('-');
                        final y = int.tryParse(parts[0]);
                        final m = int.tryParse(parts[1]);
                        if (y != null && m != null) forMonthLabel = monthLabelOf(DateTime(y, m), withYear: true);
                      }

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        // YANGI: qatorga bosilsa — o'sha to'lov uchun
                        // muvaffaqiyat oynasi (chek + SMS/Chek/Telegram
                        // tugmalari) qayta ochiladi.
                        onTap: () => showPaymentSuccessDialog(
                          studentName: studentName,
                          amount: p['amount'] as double,
                          date: date,
                          method: method,
                          parentPhone: parentPhone,
                          forMonthLabel: forMonthLabel,
                        ),
                        child: Container(
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
                                  color: (isLocked ? const Color(0xFF94A3B8) : const Color(0xFF10B981)).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isLocked ? Icons.lock_rounded : Icons.check_circle_outline_rounded,
                                  color: isLocked ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${currencyFormat.format(p['amount'])} so'm", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B))),
                                    const SizedBox(height: 2),
                                    Text(
                                      forMonthLabel != null
                                          ? "$methodLabel · ${DateFormat('dd.MM.yyyy').format(date)} · $forMonthLabel uchun"
                                          : "$methodLabel · ${DateFormat('dd.MM.yyyy').format(date)}",
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                              if (isLocked)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFFCBD5E1)),
                                )
                              else
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8), size: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      showAddPaymentDialog(
                                        context,
                                        paymentController,
                                        studentName,
                                        parentPhone: parentPhone,
                                        existingPayment: p,
                                      );
                                    } else if (value == 'delete') {
                                      _confirmDelete(context, p);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: Color(0xFF3B82F6)), SizedBox(width: 10), Text("Tahrirlash")]),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)), SizedBox(width: 10), Text("O'chirish", style: TextStyle(color: Color(0xFFDC2626)))]),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          }),
        ),

        // --- PASTDA QOTIRILGAN "To'lov qo'shish" TUGMASI ---
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () => showAddPaymentDialog(
                context,
                paymentController,
                studentName,
                parentPhone: parentPhone,
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text("To'lov qo'shish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5)),
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// TO'LIQ EKRAN RASM KO'RISH — pinch-to-zoom (InteractiveViewer), Hero
// animatsiyasi bilan kichik doiradan silliq o'tadi, yopish uchun "X"
// tugmasi yoki pastga/tashqariga bosish.
// =========================================================================
class _FullscreenPhotoView extends StatelessWidget {
  final String photoUrl;
  final String heroTag;

  const _FullscreenPhotoView({required this.photoUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: heroTag,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                    errorBuilder: (context, error, stack) => const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}