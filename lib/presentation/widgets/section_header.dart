import 'package:flutter/material.dart';
import '../../core/constants.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kTextSecondary,
            letterSpacing: 0.5,
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
