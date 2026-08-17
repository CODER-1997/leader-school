import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isLocked; // Qulfcha holati uchun yangi parametr

  const CustomCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.isLocked = true, // Odatiy holatda qulfcha turadi
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), // Juda yumshoq va zamonaviy soya
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ikonka va uning orqa foni (Soft background)
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 30, color: iconColor),
            ),
            const SizedBox(width: 20),

            // Asosiy matnlar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700, // Qalin va chiroyli shrift
                      color: Color(0xFF1E293B), // To'q kulrang (Qoradan ko'ra chiroyliroq)
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8), // Zamonaviy och kulrang
                    ),
                  ),
                ],
              ),
            ),

            // O'ng tomondagi harakat tugmasi (Agar isLocked true bo'lsa qulfcha, aks holda strelka chiqadi)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isLocked ? Icons.lock_outline_rounded : Icons.arrow_forward_ios,
                size: 16,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}