import 'package:flutter/material.dart';
import '../../core/constants.dart';

class PnlBadge extends StatelessWidget {
  final double percent;

  const PnlBadge({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    final isPositive = percent >= 0;
    final color = isPositive ? kGain : kLoss;
    final bg = isPositive
        ? const Color(0xFFD1FAE5)
        : const Color(0xFFFEE2E2);
    final sign = isPositive ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$sign${percent.toStringAsFixed(2)}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
