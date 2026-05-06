import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../core/constants.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;
  final Widget? trailing;
  final Color? backgroundColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
    this.trailing,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kPad),
      decoration: BoxDecoration(
        color: backgroundColor ?? kCard,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kDivider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kTextSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const Gap(4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? kTextPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const Gap(2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class SmallStatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const SmallStatRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: kTextSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? kTextPrimary,
          ),
        ),
      ],
    );
  }
}
