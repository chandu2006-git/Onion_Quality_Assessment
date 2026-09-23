import 'dart:math';

/// Generates the inspection identifier used for the whole inspection session.
///
/// Format: `INS-YYYY-XXXXXX` where the six-character suffix is drawn from an
/// ambiguity-free alphabet. The identifier is always generated at runtime —
/// there is no seeded or hard-coded inspection ID anywhere in the product.
String generateInspectionId({DateTime? now, Random? random}) {
  final year = (now ?? DateTime.now()).year;
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final generator = random ?? Random.secure();
  final suffix = String.fromCharCodes(
    List<int>.generate(6, (_) => alphabet.codeUnitAt(generator.nextInt(alphabet.length))),
  );
  return 'INS-$year-$suffix';
}

/// Formats a timestamp for display and for the inspection report.
String formatInspectionTimestamp(DateTime moment) {
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = moment.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = months[local.month - 1];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day $month ${local.year}, $hour:$minute';
}
