import 'package:flutter/material.dart';

import 'school_classes_tab.dart';
import 'school_absentees_tab.dart';
import 'school_all_students_view.dart';

/// MUHIM: klass nomi "SchoolView" saqlab qolindi — shu bilan boshqa
/// ekranlardan `SchoolView()` deb chaqirilgan joylar BUZILMAYDI, faqat
/// ICHKI tuzilishi o'zgardi: endi 3 ta bo'limli BottomNav qobig'i.
///
/// Bo'limlar:
///   1. Sinflar — AYNAN avvalgi SchoolView tanasi (SchoolClassesTab).
///   2. Kelmaganlar — YANGI, ikki bosqichli: Sinf -> Fan -> O'quvchilar.
///   3. O'quvchilar — YANGI: maktabdagi barcha o'quvchilar, qidiruv bilan.
class SchoolView extends StatefulWidget {
  const SchoolView({super.key});

  @override
  State<SchoolView> createState() => _SchoolViewState();
}

class _SchoolViewState extends State<SchoolView> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    SchoolClassesTab(),
    SchoolAbsenteesTab(),
    SchoolAllStudentsView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF3B82F6),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.class_outlined),
              activeIcon: Icon(Icons.class_rounded),
              label: "Sinflar",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_off_outlined),
              activeIcon: Icon(Icons.person_off_rounded),
              label: "Kelmaganlar",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups_rounded),
              label: "O'quvchilar",
            ),
          ],
        ),
      ),
    );
  }
}