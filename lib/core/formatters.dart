import 'package:intl/intl.dart';

String formatCurrency(double amount, {String symbol = '₹'}) {
  if (amount.abs() >= 10000000) {
    return '$symbol${(amount / 10000000).toStringAsFixed(2)}Cr';
  } else if (amount.abs() >= 100000) {
    return '$symbol${(amount / 100000).toStringAsFixed(2)}L';
  } else if (amount.abs() >= 1000) {
    return '$symbol${NumberFormat('#,##,##0.00', 'en_IN').format(amount)}';
  }
  return '$symbol${amount.toStringAsFixed(2)}';
}

String formatDate(DateTime dt) =>
    DateFormat('d MMM yyyy').format(dt);

String formatDateTime(DateTime dt) =>
    DateFormat('d MMM, h:mm a').format(dt);

String formatTime(DateTime dt) =>
    DateFormat('h:mm a').format(dt);

String relativeDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(date).inDays;
  if (diff == 0) return 'Today, ${formatTime(dt)}';
  if (diff == 1) return 'Yesterday, ${formatTime(dt)}';
  return formatDate(dt);
}
