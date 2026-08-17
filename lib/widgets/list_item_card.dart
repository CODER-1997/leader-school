import 'package:flutter/material.dart';

class ListItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Color iconBgColor;

  const ListItemCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.iconBgColor = const Color(0xFFF1F5F9),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Chapdagi ikonka
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      title.isNotEmpty ? title.substring(0, 1).toUpperCase() : '?',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Matnlar qismi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),

                // Tahrirlash va O'chirish uchun chiroyli kichik tugmalar (Oddiy nuqta o'rniga)
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF3B82F6)), // Zamonaviy ko'k qalam
                    onPressed: onEdit,
                    tooltip: "Tahrirlash",
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)), // Zamonaviy qizil o'chirgich
                    onPressed: onDelete,
                    tooltip: "O'chirish",
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}