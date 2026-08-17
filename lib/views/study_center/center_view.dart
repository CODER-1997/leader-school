import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/list_item_card.dart';

class CenterView extends StatelessWidget {
  const CenterView({super.key});

  @override
  Widget build(BuildContext context) {
    // Vaqtincha test ma'lumotlar
    final List groups = [
      {'id': 'ielts1', 'name': 'IELTS Foundation', 'time': 'Dush-Chor-Juma 14:00'},
      {'id': 'math_eng', 'name': 'Matematika (Ingliz)', 'time': 'Sesh-Pay-Shan 16:30'},
      {'id': 'sat_1', 'name': 'SAT Math', 'time': 'Dush-Chor-Juma 16:00'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          "O'quv Markaz Guruhlari",
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return ListItemCard(
            title: group['name'],
            subtitle: group['time'],
            iconBgColor: const Color(0xFFECFDF5), // Ochiq yashil rang
            onTap: () {
              // Guruh bosilganda to'g'ridan-to'g'ri "Yo'qlama" oynasiga o'tadi
              Get.snackbar("Yo'qlama", "${group['name']} ro'yxati ochilmoqda...");
              // Get.to(() => AttendanceView(groupId: group['id']));
            },
          );
        },
      ),
    );
  }
}